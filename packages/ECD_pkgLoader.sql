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
            p_ctx.input_xml,
            '//CDA/currency/text()'
         )
      );

   -- дата заключения договора
   l_ctx.accept_date :=
      ECD_loader_Xml.get_date_val(
         p_ctx.input_xml,
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
CREATE PROCEDURE load_core(
   IN OUT p_ctx ECD_loader_types.ctx_t
)
AS
$procedure$
   #package
   #private
BEGIN
   /*
      Здесь позже будет:
      CALL ECD_loader_main.load_contract_core(p_ctx);
   */

   CALL ECD_loader_Ret.put_Info(
      'cda',
      'Каркас ECD_pkgLoader подключен. Внутренняя orchestration-логика еще не реализована.'
   );

   CALL set_Result (
      p_ctx,
      RET_FAIL,
      'ECD_pkgLoader.load: ECD_loader_main.load_contract_core еще не подключен.'
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

   -- инициализация временной таблицы 
   -- для возвращаемых параметров
   CALL ECD_loader_Ret.ret_Init();
   CALL ECD_loader_Ret.ret_Clear();

   p_result_code := RET_FAIL;
   p_result_info := NULL;

   CALL ECD_loader_log.dbg('ECD_pkgLoader.load: begin');

   IF p_cdata_xml IS NULL OR btrim(p_cdata_xml) = '' THEN
      p_result_info := 'Переданный XML договора пуст.';
      CALL ECD_loader_Ret.put_Error( 'cda', p_result_info );
      RETURN;
   END IF;

   BEGIN
      l_input_xml := xmlparse( document p_cdata_xml );
   EXCEPTION
      WHEN OTHERS THEN
         p_result_info := 'Переданный XML договора не является валидным.';
         CALL ECD_loader_Ret.put_Error( 'cda', p_result_info );
         RETURN;
   END;

   BEGIN
      IF p_cparameters_xml IS NOT NULL AND btrim(p_cparameters_xml) <> '' THEN
         l_params_xml := xmlparse(document p_cparameters_xml);
      ELSE
         l_params_xml := NULL;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         p_result_info := 'Переданный XML параметров не является валидным.';
         CALL ECD_loader_Ret.put_Error('cda', p_result_info);
         RETURN;
   END;

   -- создаем контекст загрузки, в нем все параметры
   -- необходимые для загрузки договора
   l_ctx := create_And_Init_Ctx( p_prvid, l_input_Xml, l_params_Xml );

   CALL load_core(l_ctx);

   p_result_code := l_ctx.result_code;
   p_result_info := l_ctx.result_info;

   CALL ECD_loader_log.dbg( 'ECD_pkgLoader.load: end, result_code = ' || coalesce(p_result_code::varchar, '<null>') );

EXCEPTION
   WHEN OTHERS THEN
      CALL ECD_loader_err.capture_unhandled(
         'ECD_pkgLoader.load',
         l_err_text
      );

      p_result_code := RET_FAIL;
      p_result_info := l_err_text;

      CALL ECD_loader_Ret.put_Error('cda', p_result_info);
END;
$procedure$


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

-- end_of_Package
;