CREATE OR REPLACE PACKAGE ecd_loader_err

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE

      cVersion CONSTANT varchar(100) := '$id: {0.1.0} {10.04.2026} Lora$';

      cErr_Prefix_Business CONSTANT varchar(30) := 'ECD_BUS_';
      cErr_Prefix_Config   CONSTANT varchar(30) := 'ECD_CFG_';
      cErr_Prefix_Data     CONSTANT varchar(30) := 'ECD_DAT_';

      g_last_error_text varchar(4000 ) := NULL;
      g_last_error_full varchar(32000) := NULL;

   BEGIN
      RAISE DEBUG 'Package "ecd_loader_err" - % - initialized', cVersion;
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

   CREATE PROCEDURE clear_last_error()
   AS
   $procedure$
   BEGIN
      g_last_error_text := NULL;
      g_last_error_full := NULL;
   END;
   $procedure$

   CREATE FUNCTION get_last_error_text()
      RETURNS varchar
   AS
   $function$
   BEGIN
      RETURN g_last_error_text;
   END;
   $function$

   CREATE FUNCTION get_last_error_full()
      RETURNS varchar
   AS
   $function$
   BEGIN
      RETURN g_last_error_full;
   END;
   $function$


   /* */
   CREATE PROCEDURE set_last_error(
      p_text varchar,
      p_full varchar DEFAULT NULL
   )
   AS
   $procedure$
   #private
   BEGIN
      g_last_error_text := p_text;
      g_last_error_full := coalesce(p_full, p_text);
   END;
   $procedure$


   /* */
   CREATE PROCEDURE raise_Business_Error (
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
      #package
   DECLARE
      l_hint varchar(4000);
   BEGIN

      l_hint := cErr_Prefix_Business || coalesce( p_code, 'UNKNOWN');

      CALL set_last_error    ( p_message, p_message );
      CALL ecd_loader_log.err('BUSINESS ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>'));

      RAISE EXCEPTION '%', coalesce(p_message, 'Business error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$


   /* */
   CREATE PROCEDURE raise_Config_Error(
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
      #package
   DECLARE
      l_hint varchar(4000);
   BEGIN
      l_hint := cErr_Prefix_Config || coalesce(p_code, 'UNKNOWN');

      CALL set_last_error(p_message, p_message);
      CALL ecd_loader_log.err('CONFIG ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>'));

      RAISE EXCEPTION '%', coalesce(p_message, 'Configuration error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$


   /* */
   CREATE PROCEDURE raise_Data_Error (
      p_code    varchar,
      p_message varchar
   )
   AS
   $procedure$
      #package
   DECLARE
      l_hint varchar(4000);
   BEGIN
      l_hint := cErr_Prefix_Data || coalesce(p_code, 'UNKNOWN');

      CALL set_last_error    ( p_message, p_message );
      CALL ecd_loader_log.err( 'DATA ERROR [' || l_hint || '] ' || coalesce(p_message, '<empty>') );

      RAISE EXCEPTION '%', coalesce( p_message, 'Data error')
         USING ERRCODE = 'P0001',
               HINT    = l_hint;
   END;
   $procedure$

--end_Of_Package
;