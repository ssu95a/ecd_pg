CREATE OR REPLACE PACKAGE ecd_loader_Cus

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
      RAISE DEBUG 'Package "ecd_loader_cus" - % - initialized', cVersion;
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


/* Завести нового клиента */
CREATE PROCEDURE create_Cus(
   IN     p_ctx         ecd_loader_types.ctx_t,
   IN     p_xml         xml,
   OUT    p_cus_Id      numeric,
   OUT    p_result_Code int4,
   OUT    p_result_Info varchar
)
AS
$procedure$
DECLARE
   l_run_Mfv int4 := 0;
BEGIN
   l_run_Mfv := coalesce( ecd_loader_Xml.get_Numeric_Val( p_ctx.params_xml, '//parameter[@name="cus_run_mfv"]/text()' ), 0 )::int4;
   CALL ecd_loader_Dep.create_Cus( p_xml, l_run_Mfv, p_cus_Id, p_result_Code, p_result_Info );
END;
$procedure$


/* Вызов handler-а клиента */
CREATE PROCEDURE run_Cus_Handler(
   IN     p_ctx          ecd_loader_types.ctx_t,
   IN     p_ent_Id       varchar,
   IN     p_cus_Id       numeric,
   IN     p_is_New       int4,
   OUT    p_result_Code  int4,
   OUT    p_result_Info  varchar
)
AS
$procedure$
DECLARE
   l_cus_Type int4 := 0;
BEGIN

   p_result_Code := RET_OK;
   p_result_Info := NULL;

   IF NOT coalesce(p_ctx.run_ffv, FALSE) THEN
      RETURN;
   END IF;

   l_cus_Type := CASE p_ent_Id
      WHEN 'cda.cus'     THEN 1
      WHEN 'cda.jnt_cus' THEN 2
      WHEN 'czo.cus'     THEN 3
      WHEN 'czo.jnt_cus' THEN 3
      ELSE 0
   END;

   CALL ecd_loader_Dep.run_Cus_Handler(
      p_cus_Id,
      p_is_New,
      l_cus_Type,
      p_ctx.agr_cur,
      p_result_Code,
      p_result_Info
   );

   IF p_result_Code = RET_OK AND p_result_Info IS NOT NULL THEN
      CALL ecd_loader_Ret.put_Info(
         p_ent_Id,
         p_result_Info,
         NULL,
         p_cus_Id::varchar
      );
   END IF;

END;
$procedure$

/* Собрать дополнительную информацию о клиенте */
CREATE PROCEDURE collect_Client_Info(
   IN p_cus_Id numeric
)
AS
$procedure$
DECLARE
   l_fio varchar(500);
BEGIN

   SELECT trim(
             coalesce(a.cCusLast_Name, '')
             || ' ' || coalesce(a.cCusFirst_Name, '')
             || ' ' || coalesce(a.cCusMiddle_Name, '')
          )
     INTO l_fio
     FROM cus a
    WHERE a.iCusNum = p_cus_Id;

   IF dm2_find.check_Extr_2(l_fio, '1000') <> 0 THEN
      CALL ecd_loader_Ret.put_Info(
         'cus',
         'Похожие ФИО контрагента найдено в базе экстремистов',
         NULL,
         p_cus_Id::varchar
      );
   END IF;

   IF account2.Check_CatGrp(0, p_cus_Id, 18, 4) THEN
      CALL ecd_loader_Ret.put_Info(
         'cus',
         'Контрагент отмечен как банкрот (КиГ-18/4)',
         NULL,
         p_cus_Id::varchar
      );
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      CALL ecd_loader_Log.err(
         'ecd_loader_Cus.collect_Client_Info: ' || SQLERRM
      );
END;
$procedure$

/* Обработка после заведения клиента */
CREATE PROCEDURE handle_After_Create(
   IN p_ctx     ecd_loader_types.ctx_t,
   IN p_xml     xml,
   IN p_ent_Id  varchar,
   IN p_cus_Id  numeric
)
AS
$procedure$
DECLARE
   l_former_L_Name varchar(100);
BEGIN

   l_former_L_Name := ecd_loader_Xml.get_String_Val(
      p_xml,
      '//former_l_name/text()'
   );

   IF l_former_L_Name IS NOT NULL THEN

      INSERT INTO cus_name_arc(
         iCusNum,
         cCusName,
         e_Date
      )
      SELECT p_cus_Id,
             l_former_L_Name,
             p_ctx.accept_date
       WHERE NOT EXISTS (
         SELECT 1
           FROM cus_name_arc a
          WHERE a.iCusNum = p_cus_Id
            AND a.cCusName = l_former_L_Name
      );

      IF FOUND THEN
         CALL ecd_loader_Ret.put_Info(
            p_ent_Id,
            'Прежняя фамилия "' || l_former_L_Name || '" сохранена для физ лица.',
            NULL,
            p_cus_Id::varchar
         );
      END IF;

   END IF;

   /*
      Здесь позже:
      - обработка EMPLOYER_CUS
      - создание/поиск работодателя как юрлица
      - связывание через cus_Action.ins_Cus_lnk
   */

END;
$procedure$

/* Поиск/создание юрлица */
CREATE PROCEDURE get_Or_Create_Jur_Cus(
   IN     p_ctx          ecd_loader_types.ctx_t,
   IN OUT p_xml          xml,
   IN     p_ent_Id       varchar,
   OUT    p_cus_Id       numeric,
   OUT    p_result_Code  int4,
   OUT    p_result_Info  varchar
)
AS
$procedure$
DECLARE
   l_inn       varchar(100);
   l_ogrn      varchar(100);
   l_cus_Type  varchar(10);

   l_found_Id  numeric;
   l_found_Inn varchar(100);
   l_found_Ogrn varchar(100);
BEGIN

   p_cus_Id      := NULL;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   l_inn      := ecd_loader_Xml.get_String_Val(p_xml, '//inn/text()');
   l_ogrn     := ecd_loader_Xml.get_String_Val(p_xml, '//GOSKOM_CODE/item[@id="OGRN"]/text()');
   l_cus_Type := ecd_loader_Xml.get_String_Val(p_xml, '//custype/text()');

   IF l_inn IS NOT NULL THEN
      BEGIN
         SELECT a.iCusNum,
                a.cCusNumNal,
                a.cCusKSiva
           INTO l_found_Id,
                l_found_Inn,
                l_found_Ogrn
           FROM cus a
          WHERE a.cCusFlag = l_cus_Type
            AND a.cCusNumNal = l_inn;

         IF l_found_Ogrn IS NOT NULL
            AND l_ogrn IS NOT NULL
            AND l_found_Ogrn <> l_ogrn
         THEN
            CALL ecd_loader_Err.raise_Data_Error(
               'JUR_CUS_BAD_OGRN',
               'У найденного клиента с ID ' || l_found_Id::varchar
               || ' не совпадает ОГРН.'
            );
         END IF;

         p_cus_Id := l_found_Id;

         CALL ecd_loader_Ret.put_Info(
            p_ent_Id,
            'Найден клиент по ИНН = ' || l_inn || ' c iCusNum = ' || p_cus_Id::varchar,
            NULL,
            p_cus_Id::varchar
         );

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
      END;
   END IF;

   IF p_cus_Id IS NULL AND l_ogrn IS NOT NULL THEN
      BEGIN
         SELECT a.iCusNum,
                a.cCusNumNal,
                a.cCusKSiva
           INTO l_found_Id,
                l_found_Inn,
                l_found_Ogrn
           FROM cus a
          WHERE a.cCusFlag = l_cus_Type
            AND a.cCusKSiva = l_ogrn;

         IF l_found_Inn IS NOT NULL
            AND l_inn IS NOT NULL
            AND l_found_Inn <> l_inn
         THEN
            CALL ecd_loader_Err.raise_Data_Error(
               'JUR_CUS_BAD_INN',
               'У найденного клиента с ID ' || l_found_Id::varchar
               || ' не совпадает ИНН.'
            );
         END IF;

         p_cus_Id := l_found_Id;

         CALL ecd_loader_Ret.put_Info(
            p_ent_Id,
            'Найден клиент по ОГРН = ' || l_ogrn || ' c iCusNum = ' || p_cus_Id::varchar,
            NULL,
            p_cus_Id::varchar
         );

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
      END;
   END IF;

   IF p_cus_Id IS NULL THEN
      CALL create_Cus(
         p_ctx,
         p_xml,
         p_cus_Id,
         p_result_Code,
         p_result_Info
      );

      IF p_result_Code <> RET_OK OR p_cus_Id IS NULL THEN
         RETURN;
      END IF;

      CALL ecd_loader_Ret.put_Info(
         p_ent_Id,
         'Заведен новый юр клиент с iCusNum = ' || p_cus_Id::varchar,
         NULL,
         p_cus_Id::varchar
      );
   END IF;

   p_result_Code := RET_OK;

EXCEPTION
   WHEN OTHERS THEN
      p_cus_Id      := NULL;
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$

/* Поиск/создание физлица */
CREATE PROCEDURE get_Or_Create_Cus(
   IN     p_ctx          ecd_loader_types.ctx_t,
   IN OUT p_xml          xml,
   IN     p_ent_Id       varchar,
   OUT    p_cus_Id       numeric,
   OUT    p_result_Code  int4,
   OUT    p_result_Info  varchar
)
AS
$procedure$
DECLARE
   l_has_Item     numeric;
   l_cus_Xml_Id   numeric;
   l_cus_Exists   numeric;
   l_cus_Type     numeric;
   l_last_Name    varchar(100);
   l_first_Name   varchar(100);
   l_birth_Date   date;

   l_doc_Type_Id  numeric;
   l_doc_Ser      varchar(20);
   l_doc_Num      varchar(20);
   l_doc_Ext_Id   varchar(100);

   l_found_Id     numeric;
   l_found_Inn    varchar(50);

   l_is_New       int4 := 0;
   l_handler_Code int4;
   l_handler_Info varchar;
BEGIN

   p_cus_Id      := NULL;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   l_has_Item   := coalesce(ecd_loader_Xml.get_Numeric_Val(p_xml, 'count(/*/*) + count(/*/@*)'), 0);
   l_cus_Xml_Id := ecd_loader_Xml.get_Numeric_Val(p_xml, '//@ICUSNUM');
   l_last_Name  := ecd_loader_Xml.get_String_Val (p_xml, '//l_name/text()');
   l_first_Name := ecd_loader_Xml.get_String_Val (p_xml, '//f_name/text()');
   l_birth_Date := ecd_loader_Xml.get_Date_Val   (p_xml, '//birth_date/text()');
   l_cus_Type   := ecd_loader_Xml.get_Numeric_Val(p_xml, '//custype/text()');

   IF l_has_Item = 0 THEN
      p_result_Code := RET_OK;
      p_cus_Id      := -2;
      RETURN;
   END IF;

   IF l_cus_Xml_Id IS NOT NULL THEN

      SELECT CASE
                WHEN EXISTS( SELECT 1 FROM cus a WHERE a.iCusNum = l_cus_Xml_Id ) THEN 1 
                ELSE 0 
             END
        INTO 
            l_cus_Exists;

      IF l_cus_Exists = 1 THEN

         p_cus_Id      := l_cus_Xml_Id;
         p_result_Code := RET_OK;

         CALL ecd_loader_Ret.put_Info (
              p_ent_Id,
              'Клиент с переданным ICUSNUM существует. iCusNum = ' || p_cus_Id::varchar,
              NULL,
              p_cus_Id::varchar
         );

         RETURN;

      ELSE

         CALL ecd_loader_Err.raise_Data_Error(
            'CUS_ID_NOT_EXISTS',
            'Клиент с ID ' || l_cus_Xml_Id::varchar || ' переданный в XML, не существует в реестре клиентов XXI.'
         );

      END IF;

   END IF;

   IF l_cus_Type IN (2, 3, 5, 6, 7) THEN

      CALL get_Or_Create_Jur_Cus(
         p_ctx,
         p_xml,
         p_ent_Id,
         p_cus_Id,
         p_result_Code,
         p_result_Info
      );
      RETURN;

   END IF;

   l_doc_Type_Id := ecd_loader_Xml.get_Numeric_Val(p_xml, '//CUS_DOC/item[@main="1"]/id_doc_tp/text()');
   l_doc_Ser     := ecd_loader_Xml.get_String_Val (p_xml, '//CUS_DOC/item[@main="1"]/doc_ser/text()');
   l_doc_Num     := ecd_loader_Xml.get_String_Val (p_xml, '//CUS_DOC/item[@main="1"]/doc_num/text()');
   l_doc_Ext_Id  := ecd_loader_Xml.get_String_Val (p_xml, '//CUS_DOC/item[@main="1"]/external_doc_type/text()');

   IF l_doc_Type_Id IS NULL AND l_doc_Ext_Id IS NOT NULL THEN

      l_doc_Type_Id := ecd_loader_Map.get_Internal_Id (
         p_ctx.provider_id,
         1,
         l_doc_Ext_Id
      )::numeric;

   END IF;

   IF l_doc_Type_Id IS NULL THEN

      CALL ecd_loader_Err.raise_Config_Error(
         'DOC_TYPE_NOT_FOUND',
         'Не возможно корректно определить тип ДУЛ физ. лица по внешнему коду "'
         || coalesce(l_doc_Ext_Id, '<NULL>') || '". Проверьте настройки.'
      );

   END IF;

   BEGIN

      SELECT c.iCusNum,
             c.cCusNumNal
        INTO l_found_Id, l_found_Inn
        FROM cus_docum d
             JOIN cus c ON c.iCusNum = d.iCusNum
       WHERE d.id_doc_tp = l_doc_Type_Id
         AND regexp_replace(d.doc_num, '\D', '', 'g') = regexp_replace(coalesce(l_doc_Num, ''), '\D', '', 'g')
         AND regexp_replace(d.doc_ser, '\D', '', 'g') = regexp_replace(coalesce(l_doc_Ser, ''), '\D', '', 'g')
         AND (l_cus_Type IS NULL OR c.cCusFlag = l_cus_Type)
         AND upper(c.cCusLast_Name)  = upper(l_last_Name)
         AND upper(c.cCusFirst_Name) = upper(l_first_Name)
         AND (l_birth_Date IS NULL OR c.dCusBirthDay = l_birth_Date);

      p_cus_Id := l_found_Id;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
           p_cus_Id := NULL;
      WHEN TOO_MANY_ROWS THEN
         CALL ecd_loader_Err.raise_Data_Error(
            'CUS_TOO_MANY_BY_DOC',
            'Не возможно определить клиента, с таким ДУЛ зарегистрировано несколько лиц'
         );
   END;

   IF p_cus_Id IS NOT NULL THEN

      IF coalesce( l_found_Inn, chr(255) )
         <>
         coalesce(
            ecd_loader_Xml.get_String_Val(p_xml, '//inn/text()'), coalesce(l_found_Inn, chr(255)) )
      THEN

         CALL ecd_loader_Err.raise_Data_Error(
            'CUS_BAD_INN',
            'Не возможно корректно определить клиента, т.к. ИНН отличается от того, который заведен в БД'
         );

      END IF;

      l_is_New := 0;

   ELSE

      CALL create_Cus(
         p_ctx,
         p_xml,
         p_cus_Id,
         p_result_Code,
         p_result_Info
      );

      IF p_result_Code <> RET_OK OR p_cus_Id IS NULL THEN
         RETURN;
      END IF;

      l_is_New := 1;

      CALL ecd_loader_Ret.put_Info (
         p_ent_Id,
         'Заведен новый клиент с iCusNum = ' || p_cus_Id::varchar,
         NULL,
         p_cus_Id::varchar
      );

   END IF;

   CALL run_Cus_Handler(
      p_ctx,
      p_ent_Id,
      p_cus_Id,
      l_is_New,
      l_handler_Code,
      l_handler_Info
   );

   IF l_handler_Code <> RET_OK THEN

      p_result_Code := RET_FAIL;
      p_result_Info := l_handler_Info;
      RETURN;

   END IF;

   IF p_cus_Id IS NOT NULL THEN
      
      CALL handle_After_Create(
         p_ctx,
         p_xml,
         p_ent_Id,
         p_cus_Id
      );

      CALL collect_Client_Info(p_cus_Id);
      
   END IF;

   p_result_Code := RET_OK;

EXCEPTION
   WHEN OTHERS THEN
      p_cus_Id      := NULL;
      p_result_Code := RET_FAIL;
      p_result_Info := SQLERRM;
END;
$procedure$

--end_Of_Package
;