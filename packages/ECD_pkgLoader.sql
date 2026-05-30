CREATE OR REPLACE PACKAGE ECD_pkgLoader

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

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


/* Инициализация контекта параметрами по умолчанию */
CREATE PROCEDURE fill_ctx_defaults (
   IN OUT p_ctx ECD_loader_Types.Ctx_t
)
AS
$procedure$
   #private
DECLARE
   l_run_ffv varchar;
BEGIN
   -- валюта договора
   p_ctx.agr_cur :=
      ecd_loader_xml.normalize_cur(
         ecd_loader_xml.get_string_val(
            p_ctx.input_xml,
            '//CDA/currency/text()'
         )
      );

   -- дата заключения договора
   p_ctx.accept_date :=
      ecd_loader_xml.get_date_val(
         p_ctx.input_xml,
         '//CDA//CDA_DATE/item[@id="accept"]/text()'
      );

   IF p_ctx.accept_date IS NULL THEN
      p_ctx.accept_date := current_date;
   END IF;

   l_run_ffv := ecd_loader_xml.get_parameter(
      p_ctx.params_xml,
      'run_ffv',
      '0'
   );
   
   p_ctx.run_ffv := coalesce(l_run_ffv, '0') = '1';

   -- TODO:
   -- Добавить получение даты покупки в контекст

END;
$procedure$


/* Основная процедура загрузки */
CREATE PROCEDURE load_core(
   IN OUT p_ctx ecd_loader_types.ctx_t
)
AS
$procedure$
#private
BEGIN
   /*
      Здесь позже будет:
      CALL ecd_loader_main.load_contract_core(p_ctx);
   */

   CALL ecd_loader_ret.ret_add_Info(
      'cda',
      'Каркас ECD_pkgLoader подключен. Внутренняя orchestration-логика еще не реализована.'
   );

   CALL ecd_loader_ctx.set_result(
      p_ctx,
      RET_FAIL,
      'ECD_pkgLoader.load: ecd_loader_main.load_contract_core еще не подключен.'
   );
END;
$procedure$


/* Загрузка одного договора из XML формата */
CREATE PROCEDURE load(
   IN  p_cData_xml       text,
   IN  p_prvId           varchar,
   IN  p_cParameters_Xml text,
   OUT p_result_Code     int4,
   OUT p_result_Info     varchar
)
AS
$procedure$
DECLARE
   l_input_xml  xml;
   l_params_xml xml;
   l_ctx        ecd_loader_types.ctx_t;
   l_err_text   varchar;
BEGIN

   -- инициализация временной таблицы 
   -- для возвращаемых параметров
   CALL ecd_loader_ret.ret_Init();
   CALL ecd_loader_ret.ret_Clear();

   p_result_code := RET_FAIL;
   p_result_info := NULL;

   CALL ecd_loader_log.dbg('ECD_pkgLoader.load: begin');

   IF p_cdata_xml IS NULL OR btrim(p_cdata_xml) = '' THEN
      p_result_info := 'Переданный XML договора пуст.';
      CALL ecd_loader_ret.ret_add_Error( 'cda', p_result_info );
      RETURN;
   END IF;

   BEGIN
      l_input_xml := xmlparse( document p_cdata_xml );
   EXCEPTION
      WHEN OTHERS THEN
         p_result_info := 'Переданный XML договора не является валидным.';
         CALL ecd_loader_ret.ret_add_Error('cda', p_result_info);
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
         CALL ecd_loader_ret.ret_add_Error('cda', p_result_info);
         RETURN;
   END;

   -- создаем контекст загрузки, в нем все параметры
   -- необходимые для загрузки договора
   l_ctx := ECD_loader_ctx.new_ctx( );

   CALL ECD_loader_ctx.init_ctx (
      l_ctx,
      p_prvid,
      l_input_xml,
      l_params_xml
   );

   CALL ECD_loader_ctx.apply_params(l_ctx);
   CALL fill_ctx_defaults(l_ctx);

   CALL load_core(l_ctx);

   p_result_code := l_ctx.result_code;
   p_result_info := l_ctx.result_info;

   CALL ecd_loader_log.dbg( 'ECD_pkgLoader.load: end, result_code = ' || coalesce(p_result_code::varchar, '<null>') );

EXCEPTION
   WHEN OTHERS THEN
      CALL ecd_loader_err.capture_unhandled(
         'ECD_pkgLoader.load',
         l_err_text
      );

      p_result_code := RET_FAIL;
      p_result_info := l_err_text;

      CALL ecd_loader_ret.ret_add_error('cda', p_result_info);
END;
$procedure$

   CREATE FUNCTION load(
      p_cdata_xml       text,
      p_prvid           varchar,
      p_cparameters_xml text
   )
      RETURNS int4
   AS
   $function$
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

;