CREATE OR REPLACE PACKAGE ECD_pkgLoader

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {30.05.2026} Lora$';

      RET_OK   CONSTANT int4 := 0;
      RET_FAIL CONSTANT int4 := -1;
   BEGIN
      RAISE DEBUG 'Package "ECD_pkgLoader" - % - initialized', cVersion;
   END;
   $init$

CREATE FUNCTION get_Version()
   RETURNS varchar
AS
$function$
BEGIN
   RETURN cVersion;
END;
$function$


/* Создать и проиницализировать Context */
CREATE FUNCTION create_And_Init_Ctx ( 
   IN  p_provider_Id varchar,
   IN  p_input_Xml   xml,
   IN  p_params_Xml  xml
)
   RETURNS 
      ECD_loader_types.ctx_t
AS
$function$
   #package
DECLARE
   l_ctx ECD_loader_types.ctx_t;
   l_val varchar;
BEGIN

   l_ctx.load_id     := gen_random_uuid();
   l_ctx.provider_id := p_provider_id;
   l_ctx.input_xml   := p_input_xml;
   l_ctx.params_xml  := p_params_xml;

   l_ctx.agr_id      := NULL;
   l_ctx.cus_id      := NULL;

   l_ctx.agr_cur     := NULL;
   l_ctx.accept_date := NULL;

   l_ctx.cus_created := FALSE;
   l_ctx.run_ffv     := FALSE;

   l_ctx.result_code := RET_FAIL;
   l_ctx.result_info := NULL;

   l_val := ECD_loader_Xml.get_Parameter(l_ctx.params_xml, 'make_working', '0');
   l_ctx.make_working := coalesce(l_val, '0') = '1';

   l_val := ECD_loader_Xml.get_parameter(l_ctx.params_xml, 'recalc_turnover_sheet', '0');
   l_ctx.recalc_turnover_sheet := coalesce(l_val, '0') = '1';

   l_val := ECD_loader_Xml.get_parameter(l_ctx.params_xml, 'ignore_check_jur_n', '0');
   l_ctx.ignore_check_jur_n := coalesce(l_val, '0') = '1';

   l_val := ECD_loader_Xml.get_parameter(l_ctx.params_xml, 'correct_schedule_percent', '0');
   l_ctx.correct_schedule_percent := coalesce(l_val, '0') = '1';

   l_val := ECD_loader_Xml.get_parameter(l_ctx.params_xml, 'fin_res_sum', NULL);
   l_ctx.fin_res_sum := l_val;

   -- валюта договора
   l_ctx.agr_cur :=
      ECD_loader_Xml.normalize_Cur (
         ECD_loader_Xml.get_string_val(
            l_ctx.input_Xml,
            '//CDA/currency/text()'
         )
      );

   -- дата заключения договора
   l_ctx.accept_date :=
      ECD_loader_Xml.get_date_val(
         l_ctx.input_xml,
         '//CDA//CDA_DATE/item[@id="accept"]/text()'
      );

   IF l_ctx.accept_date IS NULL THEN
      l_ctx.accept_date := current_date;
   END IF;

   l_val := ECD_loader_Xml.get_parameter(
      l_ctx.params_xml,
      'run_ffv',
      '0'
   );
   
   l_ctx.run_ffv := coalesce( l_val, '0') = '1';

   RETURN l_ctx;

END;
$function$


/* */
CREATE PROCEDURE set_Result (
   IN OUT p_ctx ECD_loader_types.ctx_t,
   IN     p_result_code int4,
   IN     p_result_info varchar
)
AS
$procedure$
   #package
   #private
BEGIN
   p_ctx.result_code := p_result_code;
   p_ctx.result_info := p_result_info;
END;
$procedure$


/* Основная процедура загрузки */
CREATE PROCEDURE load_Core (
   IN OUT p_ctx ECD_loader_Types.Ctx_t
)
AS
$procedure$
   #package
   #private
DECLARE
   l_cus_xml      xml;
   l_cus_id       numeric;
   l_agr          ECD_loader_Types.Agr_t;

   l_result_Code  int4;
   l_result_Info  varchar(4000);

BEGIN

   call ECD_loader_Ret.put_Info('cda','ECD_pkgLoader.load_Core: begin');

   -- 1. Клиент договора
   l_cus_xml := ecd_loader_xml.get_Xml_Val (
      p_ctx.input_xml,
      '//CDA/CDA_CUS'
   );

   CALL ECD_loader_Cus.get_Or_Create_Cus (
      p_ctx,
      l_cus_xml,
      'cda.cus',
      l_cus_id,
      l_result_code,
      l_result_info
   );

   IF l_result_code <> RET_OK OR l_cus_id IS NULL OR l_cus_id <= 0 THEN
      
      p_ctx.result_code := RET_FAIL;
      p_ctx.result_info := coalesce( l_result_info, 'Невозможно загрузить данные клиента.' );

      CALL ecd_loader_ret.put_Error(
         'cda',
          p_ctx.result_info
      );

      RETURN;

   END IF;

   p_ctx.cus_id := l_cus_Id;

   CALL ecd_loader_ret.put_Data(
      'cda.cus',
      NULL,
      l_cus_id::varchar
   );

   /*
      2. Договор
      Внутри load_Agr:
      - parse_Agr
      - prepare_Rate
      - resolve_Mda
      - resolve_Agr_Id
      - validate_Agr
      - resolve_Purchase
      - create_Agr
      - load_History
      - save_Meta / save_Purpose / save_Ifrs / save_Psk / save_Uuid / link_To_Pfl
   */
   CALL ecd_loader_Agr.load_Agr(
      p_ctx,
      l_cus_id,
      l_agr
   );

   IF l_agr.agr_id IS NULL THEN

      p_ctx.result_code := RET_FAIL;
      p_ctx.result_info := 'Договор не создан: не сформирован agr_id.';

      CALL ecd_loader_ret.put_Error(
         'cda',
         p_ctx.result_info
      );

      RETURN;

   END IF;

   p_ctx.agr_id := l_agr.agr_id;

   CALL ecd_loader_ret.put_Data(
      'cda',
      NULL,
      l_agr.agr_id::varchar
   );

   /*
      3. Графики
      Stage 1: грузим весь готовый блок графиков.
   */
   CALL ECD_loader_Schedule.load_All(
      p_ctx,
      l_agr.agr_id,
      p_ctx.input_xml
   );

   /*
      4. Счета договора
   */
   CALL ecd_loader_Acc.load_Acc_List(
      p_ctx,
      l_agr.agr_id,
      p_ctx.input_xml,
      l_result_code,
      l_result_info
   );

   IF l_result_code <> RET_OK 
   THEN

      p_ctx.result_code := RET_FAIL;
      p_ctx.result_info := coalesce( l_result_info, 'Ошибка при загрузке счетов договора.' );

      CALL ecd_loader_ret.put_Error(
         'cda',
         p_ctx.result_info,
         NULL,
         l_agr.agr_id::varchar
      );

      RETURN;

   END IF;

   /*
      5. Stage 1 success
   */
   p_ctx.result_code := RET_OK;
   p_ctx.result_info := 'Успешно заведен договор с ID ' || l_agr.agr_id::varchar;

   CALL ecd_loader_ret.put_Info(
      'cda',
      p_ctx.result_info,
      NULL,
      l_agr.agr_id::varchar
   );

   RAISE DEBUG 'ECD_pkgLoader.load_Core: success, agr_id=%', l_agr.agr_id;

EXCEPTION
   WHEN OTHERS THEN
      p_ctx.result_code := RET_FAIL;
      p_ctx.result_info := SQLERRM;

      CALL ecd_loader_ret.put_Error(
         'cda',
         p_ctx.result_info,
         NULL,
         coalesce(p_ctx.agr_id::varchar, NULL)
      );
END;
$procedure$


/* Загрузка одного договора из XML формата */
CREATE PROCEDURE load (
   IN  p_cData_xml       text,
   IN  p_prvId           varchar,
   IN  p_cParameters_Xml text,
   OUT p_result_Code     int4,
   OUT p_result_Info     varchar
)
AS
$procedure$
   #package
DECLARE
   l_input_xml  xml;
   l_params_xml xml;
   l_ctx        ECD_loader_types.ctx_t;
   l_err_text   varchar;
BEGIN

   -- 1. инициализация временной таблицы 
   -- для возвращаемых параметров
   CALL ECD_loader_Ret.ret_Init();
   CALL ECD_loader_Ret.ret_Clear();

   p_result_code := RET_FAIL;
   p_result_info := NULL;

   CALL ECD_loader_log.dbg( 'ECD_pkgLoader.load: begin' );

   -- 2. Разбор входного XML с данными
   -- весь XML ожидается в текстовом виде, пригодным для разбора
   -- в случае ошибки ловим ее в общем обработчике исключений
   IF p_cdata_xml IS NULL OR btrim(p_cdata_xml) = '' THEN
      p_result_info := 'Переданный XML договора пуст.';
      CALL ECD_loader_Ret.put_Error( 'cda', p_result_info );
      RETURN;
   END IF;

   l_input_xml := p_cData_Xml::xml;
   
   --   3. Разбор XML параметров
   IF p_cparameters_xml IS NOT NULL
   THEN
      l_params_xml := p_cparameters_xml::xml;
   ELSE
      l_params_xml := NULL;
   END IF;

   -- создаем контекст загрузки, в нем все параметры
   -- необходимые для загрузки договора
   l_ctx := ECD_pkgLoader.create_And_Init_Ctx( p_prvid, l_input_Xml, l_params_Xml );


   -- гланая процедура загрузки, 
   -- решает только бизнес задачи
   CALL ECD_pkgLoader.load_core(l_ctx);

   p_result_code := l_ctx.result_code;
   p_result_info := l_ctx.result_info;

   -- Если load_Core по какой-то причине не выставил текст результата.
   IF p_result_Code IS NULL THEN
      p_result_Code := RET_FAIL;
   END IF;

   IF p_result_Info IS NULL THEN
      IF p_result_code = RET_OK THEN
         p_result_info := 'Загрузка завершена успешно.';
      ELSE
         p_result_info := 'Загрузка завершена с ошибкой без текста диагностики.';
      END IF;
   END IF;

   CALL ECD_loader_log.dbg( 'ECD_pkgLoader.load: end, result_code = ' || coalesce(p_result_code::varchar, '<null>') );

EXCEPTION

      WHEN OTHERS THEN
         DECLARE
            ex TS.T_StackedDiagnostics;
            l_err_text varchar;
         BEGIN
           GET STACKED DIAGNOSTICS                       
               ex.RETURNED_SQLSTATE    = RETURNED_SQLSTATE,  
               ex.MESSAGE_TEXT         = MESSAGE_TEXT,
               ex.PG_EXCEPTION_DETAIL  = PG_EXCEPTION_DETAIL,
               ex.PG_EXCEPTION_HINT    = PG_EXCEPTION_HINT,
               ex.PG_EXCEPTION_CONTEXT = PG_EXCEPTION_CONTEXT;   
         
               l_err_text := TS.WhenOthersError('ECD_pkgLoader.load', ex);

               CALL ecd_loader_Log.err (  l_err_text );

               p_result_code := RET_FAIL;
               p_result_info := l_err_text;

               CALL ECD_loader_Ret.put_Error('cda', '[CDA]: ' || l_err_text);

               RAISE DEBUG 'ECD_pkgLoader.load failed: %', l_err_text;

         END; 

END;
$procedure$


/*
CREATE FUNCTION load (
   p_cdata_xml       text,
   p_prvid           varchar,
   p_cparameters_xml text
)
   RETURNS int4
AS
$function$
   #package
DECLARE
   l_result_code int4;
   l_result_info varchar;
BEGIN
   CALL load(
      p_cdata_xml       => p_cdata_xml,
      p_prvid           => p_prvid,
      p_cparameters_xml => p_cparameters_xml,
      p_result_code     => l_result_code,
      p_result_info     => l_result_info
   );
   RETURN l_result_code;
END;
$function$
*/
-- end_of_Package
;