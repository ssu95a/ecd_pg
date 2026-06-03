CREATE OR REPLACE PACKAGE ecd_loader_types

   CREATE TYPE Ctx_t AS (
      load_id                   uuid,
      provider_id               varchar(100),
      input_xml                 xml,
      params_xml                xml,

      agr_id                    numeric,
      cus_id                    numeric,

      agr_cur                   varchar(3),
      accept_date               date,

      cus_created               boolean,
      run_ffv                   boolean,

      make_working              boolean,
      recalc_turnover_sheet     boolean,
      ignore_check_jur_n        boolean,
      correct_schedule_percent  boolean,

      fin_res_sum               varchar(20),

      result_code               int4,
      result_info               varchar(4000)
   )

   /* Тип для хранения данных договора */
   CREATE TYPE Agr_t AS (
      agr_id              numeric,
      cus_id              numeric,

      ext_num             varchar(100),
      ext_id              varchar(100),

      mda_id              numeric,
      mak_external_id     varchar(100),

      dt_buy              date,
      dt_end              date,
      d_sign              date,
      d_first_pay_a       date,
      d_original          date,
      d_original_end      date,
      d_date_of_issue     date,

      total_sum           numeric,
      amount_agr          numeric,
      pay_sum             numeric,
      premium_sum         numeric,

      ext_percent         numeric,
      psk                 numeric,

      purchase_type       numeric,
      coeff_discount      numeric,
      initial_id          varchar(100),

      ntime_y             int4,
      ntime_m             int4,
      ntime_d             int4,

      purpose_id          numeric,
      purpose_num         varchar(100),

      pfl_id              numeric,
      pfl_num             varchar(100),

      fin_res             varchar(20),
      owd                 varchar(10),
      uuid                varchar(100),

      annuity_day         int4,
      icdhstdid           numeric,
      msfo_std            varchar(100),
      msfo_seg            varchar(100),

      cda_note            varchar(2000),
      optional_attrs      xml,
      parts_xml           xml,
      jnt_cus_xml         xml
   )

   /* Тип для хранения данных части договора */
   CREATE TYPE Part_t AS (
      agr_id                      numeric,
      part_no                     numeric,

      dt_buy                      date,
      dt_end                      date,

      ext_percent                 numeric,
      penalty_debt                numeric,
      penalty_percent             numeric,
      penalty_overdue             numeric,

      amount_agr                  numeric,
      current_percent_sum         numeric,
      overdue_sum                 numeric,
      overdue_percent_sum         numeric,
      fine_main_sum               numeric,
      fine_percent_sum            numeric,

      current_percent_overdue_sum numeric,
      overdue_percent_overdue_sum numeric,
      commission_sum              numeric,

      days_of_delay               int4,
      days_of_delay_percent       int4,
      rate_on_overdue_debt        numeric,
      days_of_delay_prc_on_ovd    int4,

      is_prol                     boolean,
      calc_percent_sum            numeric
   )

   CREATE FUNCTION __init__()
      RETURNS void
   AS
   $init$
   #export off
   DECLARE
      cVersion CONSTANT varchar(100) := '$id: {0.2.0} {02.06.2026} Lora$';
   BEGIN
      RAISE DEBUG 'Package "ecd_loader_types" - % - initialized', cVersion;
   END;
   $init$


   /* */
   CREATE FUNCTION get_Version()
      RETURNS 
         VARCHAR
   AS
   $function$
   BEGIN
      RETURN cVersion;
   END;
   $function$

;