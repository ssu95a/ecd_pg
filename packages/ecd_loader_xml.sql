CREATE OR REPLACE PACKAGE ecd_loader_Xml
   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
      #export off
   DECLARE
      
      cVersion CONSTANT varchar(100) := '$id: {0.2.1} {04.06.2026} Lora$';

      FORMAT_MONEY   CONSTANT varchar(50) := 'FM9999999999999999.99';
      FORMAT_PERCENT CONSTANT varchar(50) := 'FM9999999999999999.99999999999999999';

      cDefault_Cur         CONSTANT varchar(3)  := 'RUR';
      cDefault_Date_Format CONSTANT varchar(30) := 'YYYY-MM-DD';

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_xml" - % - initialized', cVersion;
   END;
   $init$


/* Версия */
CREATE FUNCTION get_version()
   RETURNS varchar
AS
$function$
   #package
BEGIN
   RETURN cVersion;
END;
$function$


/* Преобразует строку в число */
CREATE FUNCTION to_numeric(
   p_text varchar
)
   RETURNS numeric
AS
$function$
   #package
DECLARE
   l_text varchar;
BEGIN
   IF p_text IS NULL OR btrim(p_text) = '' THEN
      RETURN NULL::numeric;
   END IF;

   l_text := btrim(p_text);

   RETURN l_text::numeric;

EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL::numeric;
END;
$function$


/* Преобразует строку в денежную сумму */
CREATE FUNCTION to_money (
   p_text varchar
)
   RETURNS numeric
AS
$function$
   #package
DECLARE
   l_text varchar;
BEGIN
   IF p_text IS NULL OR btrim(p_text) = '' THEN
      RETURN NULL;
   END IF;

   l_text := replace(regexp_replace(p_text, '[^,.0-9-]', '', 'g'), ',', '.');

   IF l_text IS NULL OR btrim(l_text) = '' THEN
      RETURN NULL;
   END IF;

   RETURN round(l_text::numeric, 2);
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
$function$


/* Преобразует строку в значение % */
CREATE FUNCTION to_percent(
   p_text varchar
)
   RETURNS numeric
AS
$function$
   #package
DECLARE
   l_text varchar;
BEGIN
   IF p_text IS NULL OR btrim(p_text) = '' THEN
      RETURN NULL;
   END IF;

   l_text := replace( regexp_replace( p_text, '[^,.0-9-]', '', 'g'), ',', '.');

   IF l_text IS NULL OR btrim(l_text) = '' THEN
      RETURN NULL;
   END IF;

   RETURN l_text::numeric;
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
$function$


/* Приводит код валюты к символьному коду, если передано как число */
CREATE FUNCTION normalize_Cur(
   p_cur varchar
)
   RETURNS varchar
AS
$function$
   #package
BEGIN
   IF p_cur IS NULL OR btrim(p_cur) = '' THEN
      RETURN cDefault_Cur;
   END IF;

   IF p_cur ~ '^[0-9]+$' THEN
      RETURN cur_util.get_cur_iso_by_code(p_cur);
   END IF;

   RETURN upper(btrim(p_cur));
END;
$function$


/* Проверка существования узла в Xml */
CREATE FUNCTION exists_Node (
   in p_xml   xml,
   in p_xpath varchar
)
   RETURNS boolean
AS
$function$
   #package
BEGIN

   IF p_xml IS NULL OR p_xpath IS NULL OR btrim(p_xpath) = '' THEN
      RETURN FALSE;
   END IF;

   RETURN xpath_exists(p_xpath, p_xml);

EXCEPTION
   WHEN OTHERS THEN
      RETURN FALSE;
END;
$function$


/* Получение части XML значения из документа XML*/
CREATE FUNCTION get_xml_Val (
   in p_xml   xml,
   in p_xpath varchar
)
   RETURNS xml
AS
$function$
   #package
DECLARE
   l_arr xml[];
BEGIN

   IF p_xml IS NULL OR p_xpath IS NULL OR btrim(p_xpath) = '' THEN
      RETURN NULL;
   END IF;

   l_arr := xpath( p_xpath, p_xml );

   IF l_arr IS NULL OR array_length(l_arr, 1) IS NULL THEN
      RETURN NULL;
   END IF;

   RETURN l_arr[1];

EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
$function$


/* Получение строкового значения из узла XML */
CREATE FUNCTION get_String_Val (
   in p_xml   xml,
   in p_xpath varchar
)
   RETURNS 
      varchar
AS
$function$
   #package
DECLARE
   l_arr xml[];
   l_ret varchar;
BEGIN
   IF p_xml IS NULL OR p_xpath IS NULL OR btrim(p_xpath) = '' THEN
      RETURN NULL;
   END IF;

   /*
      string(...) дает строковое значение XPath-выражения,
      близкое по смыслу к Oracle XMLTYPE.getStringVal()
   */
   l_arr := xpath('string(' || p_xpath || ')', p_xml);

   IF l_arr IS NULL OR array_length(l_arr, 1) IS NULL THEN
      RETURN NULL;
   END IF;

   l_ret := l_arr[1]::varchar;

   IF l_ret IS NOT NULL THEN
      l_ret := nullif(btrim(l_ret), '');
   END IF;

   RETURN l_ret;

EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
$function$


/* */
CREATE FUNCTION get_numeric_val(
   p_xml   xml,
   p_xpath varchar
)
   RETURNS numeric
AS
$function$
   #package
BEGIN
   RETURN ECD_loader_Xml.to_numeric( ECD_loader_Xml.get_string_val(p_xml, p_xpath) );
END;
$function$


/* */
CREATE FUNCTION get_money_val(
   p_xml   xml,
   p_xpath varchar
)
   RETURNS numeric
AS
$function$
   #package
BEGIN
   RETURN ECD_loader_Xml.to_money( ECD_loader_Xml.get_string_val(p_xml, p_xpath));
END;
$function$


/* */
CREATE FUNCTION get_percent_val(
   p_xml   xml,
   p_xpath varchar
)
   RETURNS numeric
AS
$function$
   #package
BEGIN
   RETURN ECD_loader_Xml.to_percent( ECD_loader_Xml.get_string_val(p_xml, p_xpath));
END;
$function$


/* */
CREATE FUNCTION get_date_val(
   p_xml    xml,
   p_xpath  varchar,
   p_format varchar DEFAULT NULL
)
   RETURNS date
AS
$function$
   #package
DECLARE
   l_text   varchar;
   l_format varchar;
BEGIN
   l_text := get_string_val(p_xml, p_xpath);
   l_format := coalesce( p_format, cDefault_Date_Format );

   IF l_text IS NULL THEN
      RETURN NULL;
   END IF;

   RETURN to_date(l_text, l_format);
EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END;
$function$


/* */
CREATE FUNCTION get_parameter(
   p_params_xml xml,
   p_name       varchar,
   p_default    varchar DEFAULT NULL
)
   RETURNS varchar
AS
$function$
   #package
DECLARE
   l_xpath varchar;
   l_value varchar;
BEGIN
   l_xpath := '//parameter[@name="' || p_name || '"]/text()';
   l_value := ECD_loader_Xml.get_string_val(p_params_xml, l_xpath);

   RETURN coalesce(l_value, p_default);
END;
$function$

;