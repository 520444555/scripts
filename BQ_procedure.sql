CREATE OR REPLACE PROCEDURE `FZ_EU_FDR_DEV.Daily_KPI_Report_Proc`()
BEGIN
 
Declare report_name string default 'Daily_KPI_Report';
Declare proc_name string default 'Daily_KPI_Report_Proc';
Declare row_count int64;
Declare frequency string default 'Daily';
Declare status string default 'Done';
Declare last_update_ts timestamp default current_timestamp;
Declare comments string default 'This reports runs Daily, starts at *:05';
--Target Table
Declare target_dataset string default (select case when split(@@project_id,'-')[OFFSET(3)] = 'dev' then 'FZ_EU_REPORT_MARTS_TABLES_DEV' else 'FZ_EU_REPORT_MARTS_TABLES_PROD' end);
Declare target_table string default 'Rule_Mart';
 
--Control Table
Declare control_table string default 'report_mart_control_table';
Declare control_tbl_dataset string default (select case when split(@@project_id,'-')[OFFSET(3)] = 'dev' then 'FZ_EU_FDR_DEV_SIT' else 'FZ_EU_FDR_PROD' end);
Declare exchg_rt_tbl string default (select case when split(@@project_id,'-')[OFFSET(3)] = 'dev' then 'FZ_EU_FDR_DEV_SIT' else 'FDREU_IHUB_VW_PROD' end);
--Start/End Date
Declare start_dt timestamp;
Declare end_dt timestamp;
 
 
 
BEGIN TRANSACTION;
--- get values of start and end date from Control Table  
EXECUTE IMMEDIATE format("""
SELECT timestamp_sub(timestamp(date(max(end_time))),interval 120 day ) as start_dt,TIMESTAMP_TRUNC(current_timestamp, DAY) as end_dt from %s.%s where report_name = '%s' and status = 'Done' 
""",control_tbl_dataset,control_table,report_name)
into start_dt, end_dt;
 
--- deleting last 120 days data with respect to createtimestamp
 
EXECUTE IMMEDIATE format("""
delete from %s.%s where date(create_timestamp)>= date('%t') and report_name='Daily_KPI_Report' """,target_dataset,target_table,start_dt);
--Insert into Target Table
EXECUTE IMMEDIATE format("""
Insert into %s.%s (
report_name
,create_timestamp
,entity
,portfolio
,FZ_channel
,class
,final_portfolio
,channel_type
,payment_source
,outcome_decision
,country_code
,customer_type
,New_Beneficiary_Flag
,receiver_transaction_currency
,sender_transaction_currency
,transaction_type
,transaction_amount_usd
,count_of_payments
Mnly_auth_fnl.Mnly_auth_amt as Mnly_auth_loss_amt,
Mnly_auth_fnl.Mnly_auth_cnt as Mnly_auth_loss_cnt,
Uk_Condor_Rps_Payments.Channel as channel_subtype,
timestamp('%t') as load_datetime
-- Required data extract from event store --
from 
(select * from  
(select *,ROW_NUMBER() OVER(PARTITION BY lifecycle_id ORDER BY event_occurred_at desc) as row_num 
from %s.event_store 
where lower(event_type) in ('transfer_initiation') 
and bq_insert_timestamp >= timestamp('%t') and bq_insert_timestamp < timestamp('%t') 
and timestamp(timestamp_millis(event_received_at)) >= timestamp('%t')
left join
-- extracting data for sub_channel derivation from Uk_Condor_Rps_Payments table --
(select * from %s.Uk_Condor_Rps_Payments) Uk_Condor_Rps_Payments
on event_store.office_id=Uk_Condor_Rps_Payments.dua_8byte_string_002
--group by create_timestamp,entity,portfolio,channel,payment_source,outcome_decision,result_type,channel_type,country_code,customer_type,decision_status,final_decision,fraud_indicator,New_Beneficiary_Flag,receiver_transaction_currency,sender_transaction_currency,transaction_type,fraud_type,alert_status,alert_indicator,class;
)""",
target_dataset,target_table,end_dt,control_tbl_dataset,start_dt,end_dt,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,control_tbl_dataset,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,control_tbl_dataset,control_tbl_dataset,start_dt,end_dt,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,start_dt,end_dt,control_tbl_dataset,start_dt,end_dt,start_dt,end_dt,control_tbl_dataset,target_dataset);
--Control Table Updates:
 
--Getting no. of records populated
set row_count=(select @@row_count);
 
--Insert into Control Table
EXECUTE IMMEDIATE format ("""
Insert into %s.%s values ('%s','%s','%s','%s','%t','%t','%s','%t','%s',cast('%d' as int64))
""", control_tbl_dataset,control_table,proc_name,report_name,target_table,frequency,start_dt,end_dt,status,last_update_ts,comments,row_count);
 
COMMIT TRANSACTION;
END
