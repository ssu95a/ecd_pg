CREATE OR REPLACE PACKAGE ECD_loader_Log

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   DECLARE
      
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {02.06.2026} Lora$';

      cLevel_Trc CONSTANT varchar(3) := 'trc';
      cLevel_Dbg CONSTANT varchar(3) := 'dbg';
      cLevel_Inf CONSTANT varchar(3) := 'inf';
      cLevel_Wrn CONSTANT varchar(3) := 'wrn';
      cLevel_Err CONSTANT varchar(3) := 'err';

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
   CALL ECD_loader_Log.log( cLevel_Dbg, p_text );
END;
$procedure$


/* */
CREATE PROCEDURE log (
   p_level varchar,
   p_text  varchar
)
AS
$procedure$
   #package
   #private
BEGIN

   CASE p_level
      WHEN cLevel_Trc THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Dbg THEN
         RAISE DEBUG   'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Inf THEN
         RAISE DEBUG  'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Wrn THEN
         RAISE DEBUG 'ecd - %', coalesce(p_text, '<empty>');
      WHEN cLevel_Err THEN
         RAISE DEBUG 'ecd - %', coalesce(p_text, '<empty>');
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
   CALL ECD_loader_Log.log(cLevel_Trc, p_text);
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
   CALL ECD_loader_Log.log(cLevel_Dbg, p_text);
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
   CALL ECD_loader_Log.log(cLevel_Inf, p_text);
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
   CALL ECD_loader_Log.log(cLevel_Wrn, p_text);
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
   CALL ECD_loader_Log.log(cLevel_Err, p_text);
END;
$procedure$

;