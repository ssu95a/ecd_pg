CREATE OR REPLACE PACKAGE ECD_loader_Map

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {02.06.2026} Lora$';
   BEGIN
      RAISE DEBUG 'Package "ecd_loader_map" - % - initialized', cVersion;
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


/* Получить внутренний ID по внешнему */
CREATE FUNCTION get_Internal_Id(
   IN p_provider_Id varchar,
   IN p_ent_Id      numeric,
   IN p_ext_Id      varchar
)
   RETURNS 
      VARCHAR
AS
$function$
DECLARE
   l_ret_Id varchar;
BEGIN

   CALL ecd_loader_Log.dbg(
      'ECD_loader_Map.get_Internal_Id: provider='
      || coalesce(p_provider_Id, '<NULL>')
      || ', ent_Id=' || coalesce( p_ent_Id::varchar, '<NULL>')
      || ', ext_Id=' || coalesce( p_ext_Id, '<NULL>')
   );

   SELECT i.ci_id::varchar
     INTO l_ret_Id
     FROM ecd_i2i i
    WHERE i.ent_id   = p_ent_Id
      AND i.cprov_id = p_provider_Id
      AND i.ce_id    = p_ext_Id;

   CALL ecd_loader_Ret.put_Data (
      p_ent_Id::varchar,
      p_ext_Id,
      l_ret_Id
   );

   RETURN l_ret_Id;

END;
$function$

/* Определение ID договора по какому-либо внешнему ID */
CREATE FUNCTION get_Cda_Id_By_Ext_Id(
   IN p_ext_Id      varchar,
   IN p_ext_Id_Type int4
)
   RETURNS numeric
AS
$function$
DECLARE
   l_ret_Id numeric;
BEGIN

   CALL ecd_loader_Log.dbg(
      'ECD_loader_Map.get_Cda_Id_By_Ext_Id: ext_Id='
      || coalesce(p_ext_Id, '<NULL>')
      || ', ext_Id_Type=' || coalesce(p_ext_Id_Type::varchar, '<NULL>')
   );

   IF p_ext_Id IS NULL THEN
      RETURN NULL;
   END IF;

   CASE p_ext_Id_Type
      WHEN 1 THEN
         SELECT a.nCdaAgrID
           INTO l_ret_Id
           FROM cda a
          WHERE a.cCdaAgrMnt = p_ext_Id
            AND a.iCdaCes    = 1;

      WHEN 2 THEN
         SELECT a.nCda2AgrID
           INTO l_ret_Id
           FROM cda2 a
          WHERE a.cCda2ExtID = p_ext_Id;

      WHEN 3 THEN
         SELECT a.nCdaAgrID
           INTO l_ret_Id
           FROM cda a
          WHERE a.nCdaAgrID = p_ext_Id::numeric;

      WHEN 4 THEN
         SELECT a.nCda2AgrID
           INTO l_ret_Id
           FROM cda2 a
          WHERE a.cCda2PrimID = p_ext_Id;

      ELSE
         RETURN NULL;
   END CASE;

   RETURN l_ret_Id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
   WHEN OTHERS THEN
      CALL ecd_loader_Log.wrn(
         'ECD_loader_Map.get_Cda_Id_By_Ext_Id: '
         || SQLERRM
      );
      RETURN NULL;
END;
$function$

/* Определение ID договора по данным XML */
CREATE FUNCTION get_Cda_Id_By_Xml(
   IN p_Xml xml
)
   RETURNS numeric
AS
$function$
DECLARE
   l_cda_Id  numeric;
   l_ext_Num varchar;
   l_ext_Id  varchar;
BEGIN

   CALL ecd_loader_Log.dbg('ECD_loader_Map.get_Cda_Id_By_Xml');

   l_cda_Id := ecd_loader_Xml.get_Numeric_Val(p_Xml, '//CDA/@NCDAAGRID');

   IF l_cda_Id IS NOT NULL THEN
      CALL ecd_loader_Ret.put_Info(
         'cda',
         'CDA: nCdaAgrID = ' || l_cda_Id::varchar
      );
      RETURN l_cda_Id;
   END IF;

   l_ext_Num := ecd_loader_Xml.get_String_Val(p_Xml, '//CDA/identifier/text()');
   l_ext_Id  := ecd_loader_Xml.get_String_Val(p_Xml, '//CDA/external_id/text()');

   l_cda_Id := get_Cda_Id_By_Ext_Id(l_ext_Num, 1);

   IF l_cda_Id IS NULL THEN
      l_cda_Id := get_Cda_Id_By_Ext_Id(l_ext_Id, 2);
   END IF;

   RETURN l_cda_Id;

END;
$function$

/* Получить ID портфеля */
CREATE FUNCTION get_CdSale_Id(
   IN p_cda_Id      numeric,
   IN p_pfl_Id      varchar,
   IN p_pfl_Id_Type int4
)
   RETURNS numeric
AS
$function$
DECLARE
   l_ret_Id numeric;
BEGIN

   CALL ecd_loader_Log.dbg(
      'ECD_loader_Map.get_CdSale_Id: cda_Id='
      || coalesce(p_cda_Id::varchar, '<NULL>')
      || ', pfl_Id=' || coalesce(p_pfl_Id, '<NULL>')
      || ', pfl_Id_Type=' || coalesce(p_pfl_Id_Type::varchar, '<NULL>')
   );

   IF p_pfl_Id IS NULL THEN
      RETURN NULL;
   END IF;

   IF p_pfl_Id_Type = 1 THEN

      SELECT a.iCdSaleId
        INTO STRICT l_ret_Id
        FROM cdsale a
       WHERE a.iCdSaleId = p_pfl_Id::numeric;

   ELSIF p_pfl_Id_Type = 2 THEN

      SELECT a.iCdSaleId
        INTO STRICT l_ret_Id
        FROM cdsale a
       WHERE a.cCdSaleNum = p_pfl_Id;

   ELSE
      RETURN NULL;
   END IF;

   CALL ecd_loader_Ret.put_Data(
      'cda.pfl.id',
      p_pfl_Id,
      l_ret_Id::varchar
   );

   RETURN l_ret_Id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      CALL ecd_loader_Ret.put_Info(
         'cda.pfl',
         'С кодом "' || p_pfl_Id || '" не найден портфель купли/продажи'
      );
      RETURN NULL;

   WHEN TOO_MANY_ROWS THEN
      CALL ecd_loader_Ret.put_Info(
         'cda.pfl',
         'С кодом "' || p_pfl_Id || '" найдено несколько портфелей купли/продажи'
      );
      RETURN NULL;
END;
$function$

/* Получить параметры приобретения из портфеля */
CREATE PROCEDURE get_Purchase_Pfl(
   IN  p_pfl_Id numeric,
   OUT p_type   numeric,
   OUT p_value  numeric
)
AS
$procedure$
BEGIN

   p_type  := NULL;
   p_value := NULL;

   IF p_pfl_Id IS NULL THEN
      RETURN;
   END IF;

   SELECT a.iCdSaleDscType,
          a.iCdSaleDsc
     INTO p_type,
          p_value
     FROM cdsale a
    WHERE a.iCdSaleId = p_pfl_Id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_type  := NULL;
      p_value := NULL;
END;
$procedure$

/* Получить тип/подтип обеспечения */
CREATE PROCEDURE get_Cz_Id(
   IN  p_code         varchar,
   IN  p_provider_Id  varchar,
   OUT p_czv_Id       numeric,
   OUT p_czw_Id       numeric,
   OUT p_is_Zal       numeric
)
AS
$procedure$
BEGIN

   p_czv_Id := NULL;
   p_czw_Id := NULL;
   p_is_Zal := NULL;

   p_czw_Id := get_Internal_Id(p_provider_Id, 3, p_code)::numeric;

   SELECT czw.nCzwCzv,
          czv.nCzvFlagZal_Gar
     INTO STRICT
          p_czv_Id,
          p_is_Zal
     FROM czw
     JOIN czv
       ON czv.iCzv = czw.nCzwCzv
    WHERE czw.iCzw = p_czw_Id;

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      CALL ecd_loader_Err.raise_Config_Error(
         'CZV_NOT_EXISTS_WITH_ID',
         'Невозможно определить подвид обеспечения XXI по внешнему коду - '
         || coalesce(p_code, '<NULL>')
         || ' для загрузчика '
         || coalesce(p_provider_Id, '<NULL>')
         || '. Проверьте настройки.'
      );
END;
$procedure$

--end_Of_Package
;