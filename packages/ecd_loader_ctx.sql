CREATE OR REPLACE PACKAGE ecd_loader_ctx

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.1.1} {10.04.2026} Lora$';

      RET_OK   CONSTANT int4 := 0;
      RET_FAIL CONSTANT int4 := -1;
   BEGIN
      RAISE DEBUG 'Package "ecd_loader_ctx" - % - initialized', cVersion;
   END;
   $init$

/* */
CREATE FUNCTION get_Version( )
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
      ecd_loader_types.ctx_t
AS
$function$
   #package
DECLARE
   l_ctx ecd_loader_types.ctx_t;
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

   l_val := ecd_loader_Xml.get_Parameter(l_ctx.params_xml, 'make_working', '0');
   l_ctx.make_working := coalesce(l_val, '0') = '1';

   l_val := ecd_loader_Xml.get_parameter(l_ctx.params_xml, 'recalc_turnover_sheet', '0');
   l_ctx.recalc_turnover_sheet := coalesce(l_val, '0') = '1';

   l_val := ecd_loader_xml.get_parameter(l_ctx.params_xml, 'ignore_check_jur_n', '0');
   l_ctx.ignore_check_jur_n := coalesce(l_val, '0') = '1';

   l_val := ecd_loader_xml.get_parameter(l_ctx.params_xml, 'correct_schedule_percent', '0');
   l_ctx.correct_schedule_percent := coalesce(l_val, '0') = '1';

   l_val := ecd_loader_xml.get_parameter(l_ctx.params_xml, 'fin_res_sum', NULL);
   l_ctx.fin_res_sum := l_val;

   RETURN l_ctx;
END;
$function$
;