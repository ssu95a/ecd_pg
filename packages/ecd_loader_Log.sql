CREATE OR REPLACE PACKAGE ECD_loader_Log

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   DECLARE
      
      cVersion CONSTANT varchar(100) := '$id: {0.1.1} {10.04.2026} Lora$';

      cLevel_Trc CONSTANT bpchar(3) := 'trc';
      cLevel_Dbg CONSTANT bpchar(3) := 'dbg';
      cLevel_Inf CONSTANT bpchar(3) := 'inf';
      cLevel_Wrn CONSTANT bpchar(3) := 'wrn';
      cLevel_Err CONSTANT bpchar(3) := 'err';

   BEGIN
      RAISE DEBUG 'Package "ECD_loader_Log" - % - initialized', cVersion;
   END;
   $init$


/* */
CREATE FUNCTION get_Version()
   RETURNS varchar
AS
$function$
   #package
BEGIN
   RETURN cVersion;
END;
$function$


/* */
CREATE PROCEDURE log(
   p_text varchar
)
AS
$procedure$
   #package
   BEGIN
   CALL log( cLevel_Dbg, p_text );
END;
$procedure$


/* */
CREATE PROCEDURE log (
   p_level bpchar,
   p_text  varchar
)
AS
$procedure$
   #package
   #private
BEGIN
   IF g_mode = cMode_Off THEN
      RETURN;
   END IF;

   IF g_mode = cMode_Raise_Only AND p_level <> cLevel_Err THEN
      RETURN;
   END IF;

   CASE p_level
      WHEN cLevel_Trc THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Dbg THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Inf THEN
         RAISE NOTICE  'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Wrn THEN
         RAISE WARNING 'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Err THEN
         RAISE WARNING 'ecd - %', coalesce(p_text, '<empty>');
      ELSE
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
   END CASE;
END;
$procedure$


/* */
CREATE PROCEDURE trc(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Trc, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE dbg(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Dbg, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE inf (
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Inf, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE wrn(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Wrn, p_text);
END;
$procedure$


/* */
CREATE PROCEDURE err(
   p_text varchar
)
AS
$procedure$
   #package
BEGIN
   CALL log(cLevel_Err, p_text);
END;
$procedure$

;