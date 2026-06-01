CREATE OR REPLACE PACKAGE K_pkgCus
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
   RAISE DEBUG 'Package "K_pkgCus" - % - initialized', cVersion;
END;
$init$


/* Версия */
CREATE FUNCTION get_Version( )
   RETURNS varchar
AS
$function$
BEGIN
   RETURN cVersion;
END;
$function$


/* Универсальная внутренняя процедура создания/обновления клиента */
CREATE PROCEDURE manage_Cus (
   IN  p_xml          xml,
   IN  p_operation    int4,   -- 1=create, 2=update
   IN  p_run_Mfv      int4,
   OUT p_cus_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
   #package
   #private
DECLARE
   l_cusData account2.cus_type;
   l_adrList xxi._cus_addr;
   l_dcmList xxi._cus_docum;
   l_telList xxi._cus_phone;
   l_emlList xxi._cus_email;
   l_gcsList ts._t_catnum;
BEGIN

   p_cus_Id      := NULL;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   RAISE DEBUG 'K_PkgCus.manage_Cus: operation=%, run_mfv=%', p_operation, p_run_Mfv;

   l_cusData := x2cus_t(p_xml);
   l_dcmList := x2dcm_List(p_xml);
   l_adrList := x2addr_List(p_xml);
   l_gcsList := x2cgs_List(p_xml);
   l_telList := x2phn_List(p_xml);
   l_emlList := x2mail_List(p_xml);

   CALL cus_action.cus_act2(
      p_cus_Id,
      p_result_Info,
      p_operation,
      l_cusData,
      l_gcsList,
      l_adrList,
      l_dcmList,
      l_telList,
      l_emlList,
      NULL,
      1,
      p_run_Mfv
   );

   IF p_cus_Id IS NULL OR p_cus_Id < 0 THEN
      
      p_result_Code := RET_FAIL;
      p_result_Info := coalesce( p_result_Info, 'Ошибка при вызове cus_action.cus_act2' );

      RETURN;

   END IF;

   /*
      Если подтвердится, что cus_action.cus_act2 в PG
      НЕ сохраняет email так же, как Oracle,
      сюда возвращается пост-обработка cus_email.
   */

   p_result_Code := RET_OK;
END;
$procedure$


/* Генерация номера клиента */
CREATE PROCEDURE generate_Cus_Num(
   IN  p_range_Id     numeric,
   IN  p_cus_Type     numeric,
   OUT p_cus_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
   #private
BEGIN
   p_cus_Id      := NULL;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   IF p_range_Id IS NOT NULL THEN
      IF NOT account2.set_Cus_Num_Range(p_range_Id::int4) THEN
         p_result_Info := 'Ошибка установки диапазона.';
         RETURN;
      END IF;
   END IF;

   p_cus_Id := account2.get_new_cus_num(p_cus_Type::int4);
   p_result_Code := RET_OK;

END;
$procedure$


/* Нормализация идентификатора страны в alpha-2 */
CREATE FUNCTION cty_AnyId_2_A2(
   IN p_any_Id varchar
)
   RETURNS char(2)
AS
$function$
   #private
DECLARE
   l_ret_A2 char(2);
   l_len    int4;
BEGIN
   IF p_any_Id IS NULL THEN
      RETURN NULL;
   END IF;

   l_len := length(p_any_Id);

   IF translate(p_any_Id, '_0123456789', '_') IS NULL THEN

      SELECT a.calpha_2
        INTO l_ret_A2
        FROM ok_sm a
       WHERE a.cdigital = p_any_Id;

      IF FOUND THEN
         RETURN l_ret_A2;
      END IF;

      RETURN NULL;
   END IF;

   IF l_len = 2 THEN
      SELECT a.calpha_2
        INTO l_ret_A2
        FROM ok_sm a
       WHERE a.calpha_2 = upper(p_any_Id);

      IF FOUND THEN
         RETURN l_ret_A2;
      END IF;
   ELSIF l_len = 3 THEN
      SELECT a.calpha_2
        INTO l_ret_A2
        FROM ok_sm a
       WHERE a.calpha_3 = upper(p_any_Id);

      IF FOUND THEN
         RETURN l_ret_A2;
      END IF;
   END IF;

   SELECT a.calpha_2
     INTO l_ret_A2
     FROM ok_sm a
    WHERE upper(a.cshortname) = upper(p_any_Id)
       OR upper(a.clongname)  = upper(p_any_Id);

   IF FOUND THEN
      RETURN l_ret_A2;
   END IF;

   RETURN NULL;
END;
$function$


/* XML -> account2.cus_type */
CREATE FUNCTION x2cus_t(
   IN p_xml xml
)
   RETURNS account2.cus_type
AS
$function$
   #private
DECLARE
   l_ret account2.cus_type;
   r     record;
BEGIN
   SELECT *
     INTO r
     FROM XMLTABLE(
        '.'
        PASSING p_xml
        COLUMNS
           external_id        varchar(100)  PATH 'external_id',
           iCusNum            numeric       PATH 'icusnum',
           cCusFlag           numeric       PATH 'custype',
           cCusRez            numeric       PATH 'resident',
           dCusOpen           date          PATH 'create_date',
           iCusOkpo           varchar(10)   PATH 'GOSKOM_CODE/item[@id="OKPO"]',
           cCusName           varchar(500)  PATH 'name',
           cCusPrim           varchar(120)  PATH 'note',
           iCusTaxNum         numeric       PATH 'tax_inspection_id',
           cCusNumNal         varchar(20)   PATH 'inn',
           iCusOtd            numeric       PATH 'iotdnum',
           cCusCoato          varchar(20)   PATH 'GOSKOM_CODE/item[@id="COAD"]',
           cCusKsiva          varchar(50)   PATH 'GOSKOM_CODE/item[@id="OGRN"]',
           iCusOkonx          numeric       PATH 'GOSKOM_CODE/item[@id="OKONH"]',
           cCusKfc            varchar(2)    PATH 'GOSKOM_CODE/item[@id="OKFS"]',
           cCusFullDoc        char(1)       PATH 'full_pack_doc',
           cCusWww            varchar(64)   PATH 'website',
           cCusSoogu          varchar(7)    PATH 'GOSKOM_CODE/item[@id="OKOGU"]',
           cCusKopf           varchar(5)    PATH 'GOSKOM_CODE/item[@id="OKOPF"]',
           iCusCup            numeric       PATH 'pension_fund_id',
           iCusCum            numeric       PATH 'foms_id',
           cCusKpp            varchar(9)    PATH 'GOSKOM_CODE/item[@id="KPP"]',
           cCusName_Sh        varchar(250)  PATH 'short_name',
           dCusBirthday       date          PATH 'birth_date',
           dCusRegDate        date          PATH 'reg_date',
           cCusRegAgency      varchar(150)  PATH 'reg_agency',
           cCusRegPlace       varchar(32)   PATH 'reg_place',
           dCusLic_Date       date          PATH 'bank_lic_date',
           cCusLicence        varchar(10)   PATH 'bank_lic_num',
           cCusAddr_English   varchar(256)  PATH 'foreign_lang_address',
           cCusNal_Sert       varchar(40)   PATH 'tax_certificate',
           cCusLast_Name      varchar(100)  PATH 'l_name',
           cCusFirst_Name     varchar(30)   PATH 'f_name',
           cCusMiddle_Name    varchar(30)   PATH 'm_name',
           cCusSubBox         varchar(25)   PATH 'postbox',
           cCusOkved          varchar(1000) PATH 'GOSKOM_CODE/item[@id="OKVD"]',
           cCusGov_Cert       varchar(32)   PATH 'reg_info',
           cCusRegn_Old       varchar(32)   PATH 'old_registration_num',
           cCusOktmo          varchar(12)   PATH 'GOSKOM_CODE/item[@id="OKTMO"]',
           cCusEin            varchar(9)    PATH 'ein',
           iCusStatus         numeric       PATH 'status',
           cCusSex            varchar(1)    PATH 'gender',
           cCusBirthPlace     varchar(250)  PATH 'birth_place',
           cCusSnils          varchar(15)   PATH 'snils',
           iDsmr              varchar(3)    PATH 'idsmr',
           cCusCountry1       varchar(10)   PATH 'country_location_code',
           cCusCountry1_2     varchar(10)   PATH 'citizenship_country',
           cCusCountry2       varchar(10)   PATH 'country_main_office_code'
     );

   l_ret.cCusInvo_Info   := r.external_id;
   l_ret.iCusNum         := r.iCusNum;
   l_ret.cCusFlag        := r.cCusFlag;
   l_ret.cCusRez         := r.cCusRez;
   l_ret.dCusOpen        := r.dCusOpen;
   l_ret.iCusOkpo        := r.iCusOkpo;
   l_ret.cCusName        := r.cCusName;
   l_ret.cCusPrim        := r.cCusPrim;
   l_ret.iCusTaxNum      := r.iCusTaxNum;
   l_ret.cCusNumNal      := r.cCusNumNal;
   l_ret.iCusOtd         := r.iCusOtd;
   l_ret.cCusCoato       := r.cCusCoato;
   l_ret.cCusKsiva       := r.cCusKsiva;
   l_ret.iCusOkonx       := r.iCusOkonx;
   l_ret.cCusKfc         := r.cCusKfc;
   l_ret.cCusFullDoc     := r.cCusFullDoc;
   l_ret.cCusWww         := r.cCusWww;
   l_ret.cCusSoogu       := r.cCusSoogu;
   l_ret.cCusKopf        := r.cCusKopf;
   l_ret.iCusCup         := r.iCusCup;
   l_ret.iCusCum         := r.iCusCum;
   l_ret.cCusKpp         := r.cCusKpp;
   l_ret.cCusName_Sh     := r.cCusName_Sh;
   l_ret.dCusBirthday    := r.dCusBirthday;
   l_ret.dCusRegDate     := r.dCusRegDate;
   l_ret.cCusRegAgency   := r.cCusRegAgency;
   l_ret.cCusRegPlace    := r.cCusRegPlace;
   l_ret.dCusLic_Date    := r.dCusLic_Date;
   l_ret.cCusLicence     := r.cCusLicence;
   l_ret.cCusAddr_English:= r.cCusAddr_English;
   l_ret.cCusNal_Sert    := r.cCusNal_Sert;
   l_ret.cCusLast_Name   := r.cCusLast_Name;
   l_ret.cCusFirst_Name  := r.cCusFirst_Name;
   l_ret.cCusMiddle_Name := r.cCusMiddle_Name;
   l_ret.cCusSubBox      := r.cCusSubBox;
   l_ret.cCusOkved       := r.cCusOkved;
   l_ret.cCusGov_Cert    := r.cCusGov_Cert;
   l_ret.cCusRegn_Old    := r.cCusRegn_Old;
   l_ret.cCusOktmo       := r.cCusOktmo;
   l_ret.cCusEin         := r.cCusEin;
   l_ret.iCusStatus      := r.iCusStatus;
   l_ret.cCusSex         := r.cCusSex;
   l_ret.cCusBirthPlace  := r.cCusBirthPlace;
   l_ret.cCusSnils       := r.cCusSnils;
   l_ret.iDsmr           := r.iDsmr;
   l_ret.cCusCountry1    := cty_AnyId_2_A2(coalesce(r.cCusCountry1, r.cCusCountry1_2));
   l_ret.cCusCountry2    := cty_AnyId_2_A2(r.cCusCountry2);

   RETURN l_ret;
END;
$function$


/* XML -> документы */
CREATE FUNCTION x2dcm_List(
   IN p_xml xml
)
   RETURNS xxi._cus_docum
AS
$function$
   #private
BEGIN
   RETURN (
      SELECT array_agg(row(y.*)::xxi.cus_docum)
        FROM (
           SELECT
              x.id_doc,
              NULL::numeric                AS iCusNum,
              CASE x.is_Main WHEN '1' THEN 'Y' ELSE 'N' END AS pref,
              x.id_doc_tp,
              NULL::numeric                AS doc_npp,
              x.doc_num,
              x.doc_ser,
              to_date(x.doc_date_s,   'YYYY-MM-DD') AS doc_date,
              x.doc_agency,
              to_date(x.doc_e_date_s, 'YYYY-MM-DD') AS doc_period,
              x.doc_subdiv,
              NULL::bytea                  AS broad_id,
              NULL::bytea                  AS photo_id,
              NULL::bytea                  AS sign_id,
              NULL::numeric                AS doc_cnt,
              NULL::timestamp              AS doc_active,
              NULL::timestamp              AS doc_active_end,
              0::numeric                   AS id_mode
             FROM XMLTABLE(
                '//CUS_DOC/item'
                PASSING p_xml
                COLUMNS
                   id_doc       numeric      PATH 'id_doc',
                   is_main      varchar(1)   PATH '@main',
                   id_doc_tp    numeric      PATH 'id_doc_tp',
                   doc_ser      varchar(20)  PATH 'doc_ser',
                   doc_num      varchar(20)  PATH 'doc_num',
                   doc_date_s   varchar(20)  PATH 'doc_date',
                   doc_e_date_s varchar(20)  PATH 'doc_expriry_date',
                   doc_agency   varchar(200) PATH 'doc_agency',
                   doc_subdiv   varchar(20)  PATH 'doc_subdiv'
             ) x
        ) y
   );
END;
$function$


/* XML -> адреса */
CREATE FUNCTION x2addr_List(
   IN p_xml xml
)
   RETURNS xxi._cus_addr
AS
$function$
   #private
BEGIN
   RETURN (
      SELECT array_agg(row(y.*)::xxi.cus_addr)
        FROM (
           SELECT
              x.id_addr,
              NULL::numeric AS iCusNum,
              x.addr_type,
              x.code,
              cty_AnyId_2_A2(coalesce(x.country, x.country_name)) AS country,
              x.post_index,
              coalesce(x.reg_num, substr(x.reg_name_kladr, 1, 2)) AS reg_num,
              coalesce(x.area, (SELECT a.cname FROM v_kladr_base a WHERE a.code = x.area_kladr)) AS area,
              coalesce(x.reg_name, (SELECT a.cname || ' ' || a.socr FROM v_kladr_base a WHERE a.code = x.reg_name_kladr)) AS reg_name,
              coalesce(x.city, (SELECT a.cname FROM v_kladr_base a WHERE a.code = x.city_kladr)) AS city,
              coalesce(x.punct_name, (SELECT a.cname FROM v_kladr_base a WHERE a.code = x.punct_name_kladr)) AS punct_name,
              coalesce(x.city_type, (SELECT a.socr FROM v_kladr_base a WHERE a.code = x.city_kladr)) AS city_type,
              coalesce(x.area_type, (SELECT a.socr FROM v_kladr_base a WHERE a.code = x.area_kladr)) AS area_type,
              coalesce(x.infr_name, (SELECT a.cname FROM v_kladr_street a WHERE a.code = x.infr_name_kladr)) AS infr_name,
              x.dom,
              coalesce(x.punct_type, (SELECT a.socr FROM v_kladr_base a WHERE a.code = x.punct_name_kladr)) AS punct_type,
              x.korp,
              x.stroy,
              coalesce(x.infr_type, (SELECT a.socr FROM v_kladr_street a WHERE a.code = x.infr_name_kladr)) AS infr_type,
              x.kv,
              x.office,
              x.porch,
              NULL::varchar      AS oksm_code,
              x.address_inline,
              x.stroy_type,
              NULL::date,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              x.addr_guid,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar,
              NULL::varchar
             FROM XMLTABLE(
                '//CUS_ADDRESS/item'
                PASSING p_xml
                COLUMNS
                   id_addr          numeric      PATH 'id_addr',
                   addr_type        numeric      PATH '@type',
                   code             varchar(20)  PATH 'code',
                   country          varchar(100) PATH 'country',
                   country_name     varchar(100) PATH 'country_name',
                   reg_num          varchar(5)   PATH 'reg_num',
                   reg_name         varchar(100) PATH 'reg_name',
                   reg_name_kladr   varchar(50)  PATH 'reg_name/@kladr_code',
                   area_type        varchar(10)  PATH 'area_type',
                   area             varchar(100) PATH 'area_name',
                   area_kladr       varchar(100) PATH 'area_name/@kladr_code',
                   city_type        varchar(100) PATH 'city_type',
                   city             varchar(100) PATH 'city',
                   city_kladr       varchar(50)  PATH 'city/@kladr_code',
                   punct_type       varchar(5)   PATH 'place_type',
                   punct_name       varchar(100) PATH 'place_name',
                   punct_name_kladr varchar(50)  PATH 'place_name/@kladr_code',
                   post_index       varchar(50)  PATH 'zipcode',
                   infr_type        varchar(10)  PATH 'infr_type',
                   infr_name        varchar(100) PATH 'infr_name',
                   infr_name_kladr  varchar(50)  PATH 'infr_name/@kladr_code',
                   dom              varchar(10)  PATH 'house',
                   korp             varchar(10)  PATH 'house_bl',
                   stroy            varchar(10)  PATH 'house_st',
                   kv               varchar(10)  PATH 'flat',
                   porch            varchar(10)  PATH 'porch',
                   office           varchar(10)  PATH 'office',
                   address_inline   varchar(1000) PATH 'non_resident_address',
                   stroy_type       numeric       PATH 'house_st_type',
                   addr_guid        varchar(100)  PATH 'fias_guid'
             ) x
        ) y
   );
END;
$function$


/* XML -> категории/группы */
CREATE FUNCTION x2cgs_List(
   IN p_xml xml
)
   RETURNS ts._t_catnum
AS
$function$
   #private
BEGIN
   RETURN (
      SELECT array_agg(row(x.iGcsCat, x.iGcsNum)::ts.t_catnum)
        FROM XMLTABLE(
           '//CUS_CG/item'
           PASSING p_xml
           COLUMNS
              iGcsCat numeric PATH '@iobcnum',
              iGcsNum numeric PATH '@iobgnum'
        ) x
   );
END;
$function$


/* XML -> телефоны */
CREATE FUNCTION x2phn_List(
   IN p_xml xml
)
   RETURNS xxi._cus_phone
AS
$function$
   #private
BEGIN
   RETURN (
      SELECT array_agg(row(y.*)::xxi.cus_phone)
        FROM (
           SELECT
              x.id_phone,
              NULL::numeric AS iCusNum,
              x.ph_type,
              NULL::numeric AS ph_npp,
              x.ph_num,
              x.ph_cnt,
              x.ph_city,
              x.ph_ext_num,
              NULL::varchar AS ph_numnum,
              x.sms,
              x.country,
              NULL::numeric AS utc,
              NULL::varchar AS accept_status,
              NULL::varchar AS active_status,
              x.remarks,
              NULL::varchar AS findnum,
              NULL::timestamp AS accept_date,
              NULL::timestamp AS check_date
             FROM XMLTABLE(
                '//CUS_PHONE/item[count(*)>0]'
                PASSING p_xml
                COLUMNS
                   id_phone   numeric      PATH 'id_phone',
                   ph_type    numeric      PATH 'phone_type',
                   ph_num     varchar(300) PATH 'phone_number',
                   ph_cnt     numeric      PATH 'country_phone_code',
                   ph_city    numeric      PATH 'city_code',
                   ph_ext_num varchar(10)  PATH 'add_code',
                   sms        varchar(1)   PATH 'sms',
                   country    varchar(5)   PATH 'country_code',
                   remarks    varchar(500) PATH 'note'
             ) x
        ) y
   );
END;
$function$


/* XML -> email */
CREATE FUNCTION x2mail_List(
   IN p_xml xml
)
   RETURNS xxi._cus_email
AS
$function$
   #private
BEGIN
   RETURN (
      SELECT array_agg(row(y.*)::xxi.cus_email)
        FROM (
           SELECT
              NULL::numeric   AS id_email,
              NULL::numeric   AS iCusNum,
              x.email         AS e_mail,
              x.email_type    AS m_type,
              '1'::varchar    AS accept_status,
              NULL::timestamp AS accept_date,
              NULL::varchar   AS active_status,
              NULL::timestamp AS check_date,
              NULL::varchar   AS unique_status,
              NULL::timestamp AS unique_date
             FROM XMLTABLE(
                '//CUS_EMAIL/item'
                PASSING p_xml
                COLUMNS
                   email_type numeric      PATH '@id',
                   email      varchar(100) PATH '.'
             ) x
            WHERE x.email IS NOT NULL
        ) y
   );
END;
$function$


/* Очистка буферов альтернативного поиска */
CREATE PROCEDURE af_Clear()
AS
$procedure$
   #private
DECLARE
   l_cusData account2.cus_type;
   l_dcmList xxi._cus_docum;
BEGIN
   af_cusData := l_cusData;
   af_dcmList := l_dcmList;
END;
$procedure$


/* Внутренняя реализация альтернативного поиска */
CREATE PROCEDURE af_Find_Cus_Int(
   IN  p_xml          xml,
   OUT p_cus_Id       numeric,
   OUT p_result_Code  int4,
   OUT p_result_Info  varchar
)
AS
$procedure$
   #private
DECLARE
   tabParamImpl  AC.T_TabParameterImpl;
   tabResultImpl AC.T_TabParameterImpl;
BEGIN
   p_cus_Id      := 0;
   p_result_Code := RET_FAIL;
   p_result_Info := NULL;

   CALL af_Clear();

   p_result_Info := 'Ошибка при загрузке данных клиента из XML';
   af_cusData := x2cus_t(p_xml);

   p_result_Info := 'Ошибка при загрузке ДУЛ клиента из XML';
   af_dcmList := x2dcm_List(p_xml);

   p_result_Info := 'Ошибка при вызове ФПЗ "ECD.AF_Cus_Finder"';
   AC.Get_TabValueImpl(tabResultImpl, 'ECD.AF_Cus_Finder', tabParamImpl);

   p_cus_Id := coalesce(tabResultImpl('o1')::numeric, 0);
   p_result_Code := RET_OK;

EXCEPTION
   WHEN OTHERS THEN
      p_cus_Id      := 0;
      p_result_Code := RET_FAIL;
      p_result_Info := 'Альтернативный поиск клиента: '|| coalesce( p_result_Info, '<NULL>') || chr(10) || SQLERRM;
END;
$procedure$

-- end_Of_Package
;