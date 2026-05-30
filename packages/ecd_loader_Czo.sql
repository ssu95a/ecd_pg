CREATE OR REPLACE PACKAGE ecd_loader_Czo

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
      RAISE DEBUG 'Package "ecd_loader_czo" - % - initialized', cVersion;
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

/* Проверка дублирования обеспечения по параметрам */
CREATE FUNCTION exists_Czo_With_Same_Params (
   IN p_agr_Id      numeric,
   IN p_acc_Doc_Num varchar,
   IN p_dt_Beg      date,
   IN p_dt_End      date,
   IN p_sum         numeric,
   IN p_cur         varchar
)
   RETURNS boolean
AS
$function$
BEGIN

   IF EXISTS (
      SELECT 1
        FROM v_czo_kb a
       WHERE a.cCdhAtribut = p_acc_Doc_Num
         AND a.nCzoAgrID   = p_agr_Id
         AND a.date_Start  = p_dt_Beg
         AND a.date_End    = p_dt_End
         AND a.nCzoSumma   = p_sum
         AND a.cCzoCur     = p_cur
   ) THEN
      RETURN TRUE;
   END IF;

   RETURN FALSE;

END;
$function$


/* Загрузка сопоручителей обеспечения */
CREATE PROCEDURE load_Jnt_Cus(
   IN  p_ctx         ecd_loader_types.ctx_t,
   IN  p_czo_Id      numeric,
   IN  p_jnt_Cus_Xml xml,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
DECLARE
   r           record;
   l_cus_Id    numeric;
   l_ret_Code  int4;
   l_ret_Info  varchar;
BEGIN

   p_result_Code := RET_OK;
   p_result_Info := NULL;

   IF p_jnt_Cus_Xml IS NULL THEN
      RETURN;
   END IF;

   FOR r IN
      SELECT *
        FROM XMLTABLE(
           'item'
           PASSING p_jnt_Cus_Xml
           COLUMNS
              iCusNum numeric PATH '@ICUSNUM',
              cus_Xml xml     PATH '.'
        )
   LOOP

      l_cus_Id := r.iCusNum;

      IF l_cus_Id IS NULL THEN
         CALL ECD_loader_Cus.get_Or_Create_Cus (
            p_ctx,
            r.cus_Xml,
            'czo.jnt_cus',
            l_cus_Id,
            l_ret_Code,
            l_ret_Info
         );
      ELSE
         l_ret_Code := RET_OK;
         l_ret_Info := NULL;
      END IF;

      IF l_ret_Code <> RET_OK OR l_cus_Id IS NULL OR l_cus_Id <= 0 THEN
         p_result_Code := RET_FAIL;
         p_result_Info := 'Обеспечение не загружено. Невозможно загрузить данные созаемщика. ' || coalesce(l_ret_Info, '<NULL>');
         RETURN;
      END IF;

      CALL ecd_loader_Ret.put_Data(
         'czo.jnt_cus',
         ecd_loader_Xml.get_String_Val(r.cus_Xml, '//external_id/text()'),
         l_cus_Id::varchar
      );

      INSERT INTO czo_jnt_cli(
         iJntCliCzoNum,
         iJntCliCusNum
      )
      SELECT
         p_czo_Id,
         l_cus_Id
       WHERE NOT EXISTS (
         SELECT 1
           FROM czo_jnt_cli a
          WHERE a.iJntCliCzoNum = p_czo_Id
            AND a.iJntCliCusNum = l_cus_Id
      );

   END LOOP;

END;
$procedure$


/* Загрузка объектов обеспечения */
CREATE PROCEDURE load_Objects(
   IN p_ctx          ecd_loader_types.ctx_t,
   IN p_czo_Id       numeric,
   IN p_dt_Beg       date,
   IN p_objects_Xml  xml,
   OUT p_result_Code int4,
   OUT p_result_Info varchar
)
AS
$procedure$
DECLARE
   r             record;
   l_extend_Id   numeric;
   l_result_Info varchar;
   l_result_Code int4;
   l_czo_Obj    CDUTIL_INTGR.T_CZOST_RC;
BEGIN

   p_result_Code := RET_OK;
   p_result_Info := NULL;

   IF p_objects_Xml IS NULL THEN
      RETURN;
   END IF;

   FOR r IN
      SELECT *
        FROM XMLTABLE(
           'item'
           PASSING p_objects_Xml
           COLUMNS
              iCzw          numeric      PATH '@ICZW',
              external_Type varchar(200) PATH 'external_type',
              name          varchar(500) PATH 'name',
              cdstr_Num     varchar(100) PATH 'cdstr_num',
              address       varchar(300) PATH 'address',
              reg_Date_S    varchar(30)  PATH 'reg_date',
              market_Date_S varchar(30)  PATH 'market_date',
              market_Sum_S  varchar(30)  PATH 'market_sum',
              area_S        varchar(30)  PATH 'area',
              cdstr_Sum_S   varchar(30)  PATH 'cdstr_sum',
              cdstr_Date_S  varchar(30)  PATH 'cdstr_date',
              likvid_Sum_S  varchar(30)  PATH 'likvid_sum',
              year_Of_S     varchar(10)  PATH 'year_of',
              opt_Attrs     xml          PATH 'OBJ_ATTRIBUTES'
        )
   LOOP

      l_extend_Id := NULL;

      /*
         Здесь позже:
         l_extend_Id := ecd_loader_Attr.create_Optional_Attrs(...)
         или отдельный helper для attribute_extend.
      */

      l_czo_Obj.NCZOSTEXTEND_ID := l_extend_Id;
      l_czo_Obj.nCzostwtype     := 6;
      l_czo_Obj.cCZOSTNAME      := r.name;
      l_czo_Obj.cCzostadress    := r.address;
      l_czo_Obj.nCzostflagval   := 0;
      l_czo_Obj.iCzoststatus    := 2;
      l_czo_Obj.nCzostfollowuse := 0;
      l_czo_Obj.nCzosobjqntt    := 1;
      l_czo_Obj.NCZOSTNTTYPE    := 0;

      l_czo_Obj.DCZOSTHDATEMARKET   := ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.market_Date_S,'') || '</x>'), '/x/text()');
      l_czo_Obj.MCZOSTHSUMMARKET    := ecd_loader_Xml.to_Money(r.market_Sum_S);
      l_czo_Obj.MCZOSTHSUMLIQUID    := ecd_loader_Xml.to_Money(r.likvid_Sum_S);
      l_czo_Obj.DCZOSTHDATECADASTRAL:= ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.cdstr_Date_S,'') || '</x>'), '/x/text()');
      l_czo_Obj.MCZOSTHSUMCADASTRAL := ecd_loader_Xml.to_Money(r.cdstr_Sum_S);
      l_czo_Obj.CCZOSTORLTCDSTR     := r.cdStr_Num;
      l_czo_Obj.DCZOSTORLTNM        := ecd_loader_Xml.get_Date_Val( xmlparse(document '<x>' || coalesce(r.reg_Date_S,'') || '</x>'), '/x/text()');
      l_czo_Obj.IZOSTORLTAREA       := ecd_loader_Xml.to_Money    ( r.area_S );
      l_czo_Obj.NCZOSOBJYEAR        := ecd_loader_Xml.to_Numeric  ( r.year_Of_S );

      BEGIN

         CALL CDUTIL_INTGR.Ins_CzoSt_Obj(
            p_result_Info,
            'I',
            p_czo_Id,
            l_czo_Obj,
            coalesce(p_dt_Beg, current_date)
         );

         IF p_result_Info IS NOT NULL THEN
            CALL ecd_loader_Ret.put_Warn(
               'czo.obj',
               'Ошибка при сохранении данных об объекте обеспечения ' || coalesce(r.cdstr_Num, '<NULL>') || '. ' || p_result_Info
            );
            CONTINUE;
         END IF;

         IF ecd_loader_Xml.to_Money(r.cdstr_Sum_S) IS NOT NULL
            AND ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.cdstr_Date_S,'') || '</x>'), '/x/text()') IS NOT NULL
            AND l_czo_Obj.iCzostId IS NOT NULL
         THEN
            INSERT INTO czost_hst(
               iCzost_HstCzostId,
               cCzost_HstTerm,
               mCzost_HstMVal,
               dCzost_HstDate
            )
            VALUES (
               l_czo_Obj.iCzostId,
               'CADASTRAL_VALUE',
               ecd_loader_Xml.to_Money(r.cdstr_Sum_S),
               ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.cdstr_Date_S,'') || '</x>'), '/x/text()')
            );
         END IF;

      EXCEPTION
         WHEN OTHERS THEN
            CALL ecd_loader_Ret.put_Warn(
               'czo.obj',
               'Ошибка при сохранении объекта обеспечения: ' || SQLERRM
            );
      END;

   END LOOP;

END;
$procedure$

/* Загрузка страхования обеспечения */
CREATE PROCEDURE load_Insurance(
   IN p_ctx           ecd_loader_types.ctx_t,
   IN p_czo_Id        numeric,
   IN p_insurance_Xml xml,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
BEGIN

   p_result_Code := RET_OK;
   p_result_Info := NULL;

   /*
      Здесь позже:
      - выделить общий пакет ecd_loader_Insurance
      - либо вынести общий helper в ecd_loader_Dep
      Пока оставляем заглушку.
   */

   IF p_insurance_Xml IS NULL THEN
      RETURN;
   END IF;

   CALL ecd_loader_Ret.put_Warn(
      'czo.insurer',
      'Загрузка страхования обеспечения пока не подключена в ecd_loader_Czo'
   );

END;
$procedure$


/* Основная загрузка обеспечения */
CREATE PROCEDURE load_Czo_List(
   IN     p_ctx          ECD_loader_types.ctx_t,
   IN     p_agr_Id       numeric,
   IN     p_xml          xml,
   OUT    p_result_Code  int4,
   OUT    p_result_Info  varchar
)
AS
$procedure$
DECLARE
   r                record;
   l_cus_Id         numeric;
   l_czv_Id         numeric;
   l_czw_Id         numeric;
   l_is_Zal         numeric;
   l_czo_Id         numeric;
   l_ret_Code       int4;
   l_ret_Info       varchar;
   l_count_All      numeric := 0;
   l_count_Loaded   numeric := 0;
   l_end_Date       date;
BEGIN

   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL ecd_loader_Log.dbg(
      'ecd_loader_Czo.load_Czo_List: agr_Id=' || coalesce(p_agr_Id::varchar, '<NULL>')
   );

   FOR r IN
      SELECT *
        FROM XMLTABLE(
           '//CDA/CDA_GUARANTEE/item'
           PASSING p_xml
           COLUMNS
              ext_Type         varchar(100) PATH 'external_type',
              dt_Beg_S         varchar(30)  PATH 'dtbeg',
              dt_End_S         varchar(30)  PATH 'dtend',
              sum_S            varchar(50)  PATH 'sum',
              market_Sum_S     varchar(50)  PATH 'market_sum',
              cur              varchar(5)   PATH 'currency',
              iCusNum          numeric      PATH 'CZO_CUS/@ICUSNUM',
              iCzw             numeric      PATH '@ICZW',
              note             varchar(1000)PATH 'note',
              attrs_Xml        xml          PATH 'CZO_ATTRIBUTES',
              cus_Xml          xml          PATH 'CZO_CUS',
              has_Cus          numeric      PATH 'count(CZO_CUS)',
              acc_Doc_Num      varchar(100) PATH 'acc_doc_num',
              jnt_Cus_Xml      xml          PATH 'CZO_JNT_CUS/item',
              objects_Xml      xml          PATH 'CZO_OBJECT/item',
              uuid             varchar(50)  PATH 'uuid',
              insurance_Xml    xml          PATH 'CZO_INSURANCE/item'
        )
   LOOP

      l_count_All := l_count_All + 1;
      l_cus_Id    := r.iCusNum;
      l_czv_Id    := NULL;
      l_czw_Id    := r.iCzw;
      l_is_Zal    := NULL;
      l_czo_Id    := NULL;
      l_ret_Code  := RET_OK;
      l_ret_Info  := NULL;

      BEGIN

         r.cur := ECD_loader_Xml.normalize_Cur(r.cur);

         IF exists_Czo_With_Same_Params (
               p_agr_Id,
               r.acc_Doc_Num,
               ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.dt_Beg_S,'') || '</x>'), '/x/text()'),
               ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.dt_End_S,'') || '</x>'), '/x/text()'),
               ecd_loader_Xml.to_Money(r.sum_S),
               r.cur
            )
         THEN
            CALL ecd_loader_Ret.put_Info (
               'czo.cus',
               'Обеспечение с учетным № документа ' || coalesce(r.acc_Doc_Num, '<NULL>') || ' с такими параметрами уже загружено. Загрузка не производится.'
            );
            CONTINUE;
         END IF;

         IF l_cus_Id IS NULL THEN

            IF coalesce(r.has_Cus, 0) > 0 THEN
               CALL ecd_loader_Cus.get_Or_Create_Cus(
                  p_ctx,
                  r.cus_Xml,
                  'czo.cus',
                  l_cus_Id,
                  l_ret_Code,
                  l_ret_Info
               );
            ELSE
               l_cus_Id   := -2;
               l_ret_Code := RET_OK;
            END IF;

            IF l_cus_Id = -2 THEN
               SELECT a.iCdaClient
                 INTO l_cus_Id
                 FROM cda a
                WHERE a.nCdaAgrID = p_agr_Id;
            END IF;

            IF l_ret_Code <> RET_OK OR l_cus_Id IS NULL OR l_cus_Id <= 0 THEN
               p_result_Info := 'Обеспечение не загружено. Невозможно загрузить данные поручителя. ' || coalesce(l_ret_Info, '<NULL>');
               CONTINUE;
            END IF;

            CALL ecd_loader_Ret.put_Data(
               'czo.cus',
               ecd_loader_Xml.get_String_Val(r.cus_Xml, '//external_id/text()'),
               l_cus_Id::varchar
            );

         END IF;

         IF l_czw_Id IS NULL THEN
            CALL ecd_loader_Map.get_Cz_Id ( r.ext_Type, p_ctx.provider_id, l_czv_Id, l_czw_Id, l_is_Zal);
         ELSE

            SELECT a.nCzwCzv
              INTO l_czv_Id
              FROM czw a
             WHERE a.iCzw = l_czw_Id;
             
         END IF;

         l_end_Date := ecd_loader_Xml.get_Date_Val ( xmlparse(document '<x>' || coalesce(r.dt_End_S,'') || '</x>'), '/x/text()' );

         IF l_end_Date IS NULL THEN

            SELECT CDTerms.Get_curEndDate(p_agr_Id) INTO l_end_Date;

         END IF;

         /*
            позже лучше перенести в ecd_loader_Dep.create_Czo(...)
         */
         SELECT CDUtil_ZO.Ins_CZO_New(
            pAgrID      => p_agr_Id,
            pSystemID   => 27,
            pFlagPackZO => 0,
            pCZV        => l_czv_Id,
            pCZW        => l_czw_Id,
            pSum        => ecd_loader_Xml.to_Money(r.sum_S),
            pSumLQ      => ecd_loader_Xml.to_Money(r.market_Sum_S),
            pCur        => r.cur,
            pCli        => l_cus_Id,
            pComment    => r.note,
            pNamePackZO => NULL,
            pStatusZO   => 2,
            pDateStart  => ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.dt_Beg_S,'') || '</x>'), '/x/text()'),
            pDateEnd    => l_end_Date,
            pNameAtrDoc => r.acc_Doc_Num,
            pAccZO      => NULL,
            pUID        => r.uuid,
            pErr        => l_ret_Info
         )
         INTO l_czo_Id;

         IF l_czo_Id IS NULL THEN
            CALL ecd_loader_Ret.put_Error(
               'czo.cus',
               'Ошибка при заведении обеспечения. ' || coalesce(l_ret_Info, '<NULL>')
            );
            CONTINUE;
         END IF;

         /*
            Здесь позже:
            - загрузка attrs_Xml
            - через отдельный пакет атрибутов
         */

         CALL load_Jnt_Cus (
            p_ctx,
            l_czo_Id,
            r.jnt_Cus_Xml,
            l_ret_Code,
            l_ret_Info
         );

         IF l_ret_Code <> RET_OK THEN
            CALL ecd_loader_Ret.put_Error(
               'czo.jnt_cus',
               coalesce(l_ret_Info, '<NULL>')
            );
         END IF;

         CALL load_Objects(
            p_ctx,
            l_czo_Id,
            ecd_loader_Xml.get_Date_Val(xmlparse(document '<x>' || coalesce(r.dt_Beg_S,'') || '</x>'), '/x/text()'),
            r.objects_Xml,
            l_ret_Code,
            l_ret_Info
         );

         CALL load_Insurance(
            p_ctx,
            l_czo_Id,
            r.insurance_Xml,
            l_ret_Code,
            l_ret_Info
         );

         l_count_Loaded := l_count_Loaded + 1;

      EXCEPTION
         WHEN OTHERS THEN
            CALL ecd_loader_Ret.put_Error(
               'czo.cus',
               'Обеспечение не загружено. Ошибка БД: ' || SQLERRM
            );
      END;

   END LOOP;

   IF l_count_All = 0 THEN
      CALL ecd_loader_Ret.put_Info(
         'czo.cus',
         'В XML отсутствуют данные об обеспечении.'
      );
   ELSE
      CALL ecd_loader_Ret.put_Info(
         'czo.cus',
         'Загружено ' || l_count_Loaded::varchar || ' записей об обеспечении из ' || l_count_All::varchar
      );
   END IF;

   p_result_Code := RET_OK;
   p_result_Info := NULL;

END;
$procedure$

--end_Of_Package
;