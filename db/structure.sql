
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;
DROP TABLE IF EXISTS `api_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `api_tokens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `digest` varchar(255) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `principal_user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_api_tokens_on_digest` (`digest`),
  KEY `index_api_tokens_on_user_id` (`user_id`),
  KEY `fk_rails_3a0b787517` (`principal_user_id`),
  CONSTRAINT `fk_rails_3a0b787517` FOREIGN KEY (`principal_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_f16b5e0447` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `attendances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendances` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `work_date` date NOT NULL,
  `checked_in_at` datetime(6) NOT NULL,
  `checked_out_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_attendances_on_employee_id_and_work_date` (`employee_id`,`work_date`),
  KEY `index_attendances_on_employee_id` (`employee_id`),
  KEY `index_attendances_on_company_id` (`company_id`),
  KEY `fk_tenant_attendances_employee_id` (`company_id`,`employee_id`),
  CONSTRAINT `fk_rails_ce4baedec1` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_rails_f71ac5cf8b` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_tenant_attendances_employee_id` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `actor_id` bigint DEFAULT NULL,
  `action` varchar(255) NOT NULL,
  `record_type` varchar(255) NOT NULL,
  `record_id` bigint NOT NULL,
  `metadata` json DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_audit_logs_on_actor_id` (`actor_id`),
  KEY `index_audit_logs_on_company_id` (`company_id`),
  KEY `fk_tenant_audit_logs_actor_id` (`company_id`,`actor_id`),
  KEY `integration_audit_lookup` (`company_id`,`record_type`,`created_at`,`id`),
  CONSTRAINT `fk_rails_2c3f85fdd5` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_fdd08af163` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_tenant_audit_logs_actor_id` FOREIGN KEY (`company_id`, `actor_id`) REFERENCES `users` (`company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `candidates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `candidates` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `full_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `position` varchar(255) NOT NULL,
  `stage` varchar(255) NOT NULL DEFAULT 'applied',
  `notes` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_candidates_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_a4f57fb3c9` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `companies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `companies` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `lock_version` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_companies_on_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `company_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `company_roles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_company_roles_on_company_id_and_key` (`company_id`,`key`),
  KEY `index_company_roles_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_e8f0ca8a6f` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cost_centers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cost_centers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `code` varchar(30) NOT NULL,
  `name` varchar(255) NOT NULL,
  `annual_budget` decimal(18,2) NOT NULL DEFAULT '0.00',
  `currency` varchar(3) NOT NULL DEFAULT 'VND',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cost_centers_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_cost_centers_on_company_id_and_code` (`company_id`,`code`),
  KEY `index_cost_centers_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_e882abfc91` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `org_budget_nonnegative` CHECK ((`annual_budget` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `departments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `departments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `code` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_departments_on_company_id_and_code` (`company_id`,`code`),
  UNIQUE KEY `index_departments_on_company_id_and_id` (`company_id`,`id`),
  KEY `index_departments_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_f911441942` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `employee_assignments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_assignments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `organization_unit_id` bigint NOT NULL,
  `job_position_id` bigint NOT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `allocation_percent` decimal(5,2) NOT NULL DEFAULT '100.00',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_employee_assignments_on_company_id_and_id` (`company_id`,`id`),
  KEY `index_employee_assignments_on_company_id` (`company_id`),
  KEY `org_assignment_employee` (`company_id`,`employee_id`),
  KEY `org_assignment_position` (`company_id`,`job_position_id`),
  KEY `org_assignment_position_unit` (`company_id`,`organization_unit_id`,`job_position_id`),
  CONSTRAINT `fk_rails_ee6d55d92d` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `org_assignment_employee` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`),
  CONSTRAINT `org_assignment_position` FOREIGN KEY (`company_id`, `job_position_id`) REFERENCES `job_positions` (`company_id`, `id`),
  CONSTRAINT `org_assignment_position_unit` FOREIGN KEY (`company_id`, `organization_unit_id`, `job_position_id`) REFERENCES `job_positions` (`company_id`, `organization_unit_id`, `id`),
  CONSTRAINT `org_assignment_unit` FOREIGN KEY (`company_id`, `organization_unit_id`) REFERENCES `organization_units` (`company_id`, `id`),
  CONSTRAINT `org_assignment_limits` CHECK (((`allocation_percent` > 0) and (`allocation_percent` <= 100) and ((`effective_to` is null) or (`effective_to` >= `effective_from`))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `employee_shift_assignments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `employee_shift_assignments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `work_shift_id` bigint NOT NULL,
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `shift_snapshot` json NOT NULL,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `shift_assignment_lookup` (`company_id`,`employee_id`,`effective_from`),
  KEY `index_employee_shift_assignments_on_company_id` (`company_id`),
  KEY `shift_assignment_shift` (`company_id`,`work_shift_id`),
  CONSTRAINT `fk_rails_3fc4573cf3` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `shift_assignment_employee` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`),
  CONSTRAINT `shift_assignment_shift` FOREIGN KEY (`company_id`, `work_shift_id`) REFERENCES `work_shifts` (`company_id`, `id`),
  CONSTRAINT `shift_assignment_dates` CHECK (((`effective_to` is null) or (`effective_to` >= `effective_from`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `employees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `employees` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `department_id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `employee_code` varchar(255) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `job_title` varchar(255) NOT NULL,
  `hired_on` date NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'active',
  `salary_cents` bigint NOT NULL DEFAULT '0',
  `annual_leave_days` decimal(5,1) NOT NULL DEFAULT '12.0',
  `bank_account` text,
  `national_id` text,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_employees_on_company_id_and_employee_code` (`company_id`,`employee_code`),
  UNIQUE KEY `index_employees_on_company_id_and_email` (`company_id`,`email`),
  UNIQUE KEY `index_employees_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_employees_on_user_id` (`user_id`),
  KEY `index_employees_on_department_id` (`department_id`),
  KEY `index_employees_on_company_id` (`company_id`),
  KEY `fk_tenant_employees_department_id` (`company_id`,`department_id`),
  KEY `fk_tenant_employees_user_id` (`company_id`,`user_id`),
  CONSTRAINT `fk_rails_0025f65a97` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`),
  CONSTRAINT `fk_rails_15ca1438d5` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_rails_dcfd3d4fc3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_tenant_employees_department_id` FOREIGN KEY (`company_id`, `department_id`) REFERENCES `departments` (`company_id`, `id`),
  CONSTRAINT `fk_tenant_employees_user_id` FOREIGN KEY (`company_id`, `user_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `positive_salary` CHECK ((`salary_cents` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `integration_connections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `integration_connections` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `public_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `code` varchar(30) NOT NULL,
  `name` varchar(150) NOT NULL,
  `signing_secret` text NOT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '0',
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_integration_connections_on_public_id` (`public_id`),
  UNIQUE KEY `index_integration_connections_on_company_id_and_code` (`company_id`,`code`),
  UNIQUE KEY `index_integration_connections_on_company_id_and_id` (`company_id`,`id`),
  KEY `index_integration_connections_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_58a2a1a994` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `integration_deliveries`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `integration_deliveries` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `integration_connection_id` bigint NOT NULL,
  `requested_by_id` bigint NOT NULL,
  `target_key` varchar(40) NOT NULL,
  `event_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `idempotency_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `payload` mediumtext NOT NULL,
  `body_digest` varchar(64) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'queued',
  `attempt_count` int NOT NULL DEFAULT '0',
  `replay_count` int NOT NULL DEFAULT '0',
  `available_at` datetime(6) NOT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `cycle_attempt_count` int NOT NULL DEFAULT '0',
  `payroll_export_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_integration_deliveries_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `delivery_idempotency` (`company_id`,`idempotency_key`),
  UNIQUE KEY `index_integration_deliveries_on_event_id` (`event_id`),
  KEY `index_integration_deliveries_on_company_id` (`company_id`),
  KEY `delivery_due` (`status`,`available_at`),
  KEY `delivery_company_connection` (`company_id`,`integration_connection_id`),
  KEY `delivery_company_requester` (`company_id`,`requested_by_id`),
  KEY `delivery_payroll_source` (`company_id`,`payroll_export_id`),
  CONSTRAINT `delivery_company_connection` FOREIGN KEY (`company_id`, `integration_connection_id`) REFERENCES `integration_connections` (`company_id`, `id`),
  CONSTRAINT `delivery_company_payroll_source` FOREIGN KEY (`company_id`, `payroll_export_id`) REFERENCES `payroll_exports` (`company_id`, `id`),
  CONSTRAINT `delivery_company_requester` FOREIGN KEY (`company_id`, `requested_by_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `fk_rails_e5d868d730` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `delivery_attempt_bounds` CHECK (((`attempt_count` >= 0) and (`attempt_count` <= 55) and (`replay_count` >= 0) and (`replay_count` <= 10))),
  CONSTRAINT `delivery_completion_time` CHECK ((((`status` = _utf8mb4'delivered') and (`delivered_at` is not null)) or ((`status` <> _utf8mb4'delivered') and (`delivered_at` is null)))),
  CONSTRAINT `delivery_cycle_bounds` CHECK (((`cycle_attempt_count` >= 0) and (`cycle_attempt_count` <= 5))),
  CONSTRAINT `delivery_status` CHECK ((`status` in (_utf8mb4'queued',_utf8mb4'retry_wait',_utf8mb4'delivered',_utf8mb4'dead_letter',_utf8mb4'blocked')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `integration_delivery_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `integration_delivery_attempts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `integration_delivery_id` bigint NOT NULL,
  `sequence` int NOT NULL,
  `http_status` int DEFAULT NULL,
  `outcome` varchar(30) NOT NULL,
  `started_at` datetime(6) NOT NULL,
  `completed_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `delivery_attempt_sequence` (`integration_delivery_id`,`sequence`),
  KEY `index_integration_delivery_attempts_on_company_id` (`company_id`),
  KEY `attempt_company_delivery` (`company_id`,`integration_delivery_id`),
  CONSTRAINT `attempt_company_delivery` FOREIGN KEY (`company_id`, `integration_delivery_id`) REFERENCES `integration_deliveries` (`company_id`, `id`),
  CONSTRAINT `fk_rails_07a4b53c1a` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `delivery_attempt_validity` CHECK (((`sequence` >= 1) and (`sequence` <= 55) and ((`http_status` is null) or ((`http_status` >= 100) and (`http_status` <= 599))) and (`completed_at` >= `started_at`)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `integration_webhooks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `integration_webhooks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `integration_connection_id` bigint NOT NULL,
  `event_id` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `event_type` varchar(100) NOT NULL,
  `body_digest` varchar(64) NOT NULL,
  `payload` mediumtext NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'received',
  `review_note` text,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `webhook_event_identity` (`integration_connection_id`,`event_id`),
  KEY `index_integration_webhooks_on_company_id` (`company_id`),
  KEY `webhook_inbox_filter` (`company_id`,`status`,`id`),
  KEY `webhook_company_connection` (`company_id`,`integration_connection_id`),
  CONSTRAINT `fk_rails_9b2b48a75c` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `webhook_company_connection` FOREIGN KEY (`company_id`, `integration_connection_id`) REFERENCES `integration_connections` (`company_id`, `id`),
  CONSTRAINT `webhook_review_status` CHECK ((`status` in (_utf8mb4'received',_utf8mb4'acknowledged',_utf8mb4'rejected'))),
  CONSTRAINT `webhook_review_timestamp` CHECK ((((`status` = _utf8mb4'received') and (`reviewed_at` is null)) or ((`status` <> _utf8mb4'received') and (`reviewed_at` is not null))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `job_positions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_positions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `organization_unit_id` bigint NOT NULL,
  `code` varchar(30) NOT NULL,
  `title` varchar(255) NOT NULL,
  `job_grade` varchar(50) DEFAULT NULL,
  `career_level` int NOT NULL DEFAULT '1',
  `approved_headcount` int NOT NULL DEFAULT '0',
  `budgeted_cost` decimal(18,2) NOT NULL DEFAULT '0.00',
  `is_critical` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_job_positions_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_job_positions_on_company_id_and_code` (`company_id`,`code`),
  UNIQUE KEY `org_position_unit_identity` (`company_id`,`organization_unit_id`,`id`),
  KEY `index_job_positions_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_d4b6373ad7` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `org_position_unit` FOREIGN KEY (`company_id`, `organization_unit_id`) REFERENCES `organization_units` (`company_id`, `id`),
  CONSTRAINT `org_position_limits` CHECK (((`career_level` between 1 and 6) and (`approved_headcount` >= 0) and (`budgeted_cost` >= 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `leave_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `employee_id` bigint NOT NULL,
  `starts_on` date NOT NULL,
  `ends_on` date NOT NULL,
  `reason` text NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'pending',
  `reviewer_id` bigint DEFAULT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_leave_requests_on_employee_id_and_starts_on_and_ends_on` (`employee_id`,`starts_on`,`ends_on`),
  KEY `index_leave_requests_on_employee_id` (`employee_id`),
  KEY `index_leave_requests_on_reviewer_id` (`reviewer_id`),
  KEY `index_leave_requests_on_company_id` (`company_id`),
  KEY `fk_tenant_leave_requests_employee_id` (`company_id`,`employee_id`),
  KEY `fk_tenant_leave_requests_reviewer_id` (`company_id`,`reviewer_id`),
  CONSTRAINT `fk_rails_1554fc19c3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_rails_5762758b72` FOREIGN KEY (`reviewer_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_a20c88ad67` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_tenant_leave_requests_employee_id` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`),
  CONSTRAINT `fk_tenant_leave_requests_reviewer_id` FOREIGN KEY (`company_id`, `reviewer_id`) REFERENCES `users` (`company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `login_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_sessions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `digest` varchar(64) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `principal_user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_login_sessions_on_digest` (`digest`),
  KEY `index_login_sessions_on_user_id` (`user_id`),
  KEY `index_login_sessions_on_expires_at` (`expires_at`),
  KEY `fk_rails_062987f65d` (`principal_user_id`),
  CONSTRAINT `fk_rails_062987f65d` FOREIGN KEY (`principal_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_8c949dd2cd` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `onboarding_cases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `onboarding_cases` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `start_date` date NOT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'preboarding',
  `checklist` json NOT NULL,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `onboarding_employee_start` (`company_id`,`employee_id`,`start_date`),
  KEY `index_onboarding_cases_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_f90713a577` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `onboarding_company_employee` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`),
  CONSTRAINT `onboarding_status` CHECK ((`status` in (_utf8mb4'draft',_utf8mb4'ready',_utf8mb4'preboarding',_utf8mb4'in_progress',_utf8mb4'blocked',_utf8mb4'probation_review',_utf8mb4'completed',_utf8mb4'cancelled')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `organization_units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `organization_units` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `cost_center_id` bigint DEFAULT NULL,
  `code` varchar(30) NOT NULL,
  `name` varchar(255) NOT NULL,
  `unit_type` varchar(255) NOT NULL,
  `headcount_limit` int NOT NULL DEFAULT '0',
  `effective_from` date NOT NULL,
  `effective_to` date DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_organization_units_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_organization_units_on_company_id_and_code` (`company_id`,`code`),
  KEY `index_organization_units_on_company_id` (`company_id`),
  KEY `org_unit_parent` (`company_id`,`parent_id`),
  KEY `org_unit_cost` (`company_id`,`cost_center_id`),
  CONSTRAINT `fk_rails_f6e4298ba8` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `org_unit_cost` FOREIGN KEY (`company_id`, `cost_center_id`) REFERENCES `cost_centers` (`company_id`, `id`),
  CONSTRAINT `org_unit_parent` FOREIGN KEY (`company_id`, `parent_id`) REFERENCES `organization_units` (`company_id`, `id`),
  CONSTRAINT `org_unit_limits` CHECK (((`headcount_limit` >= 0) and ((`effective_to` is null) or (`effective_to` >= `effective_from`))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `outbox_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `outbox_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `event_type` varchar(255) NOT NULL,
  `payload` json NOT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_outbox_events_on_delivered_at_and_id` (`delivered_at`,`id`),
  KEY `index_outbox_events_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_32a2e9ca6f` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pay_runs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pay_runs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `period` date NOT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'draft',
  `created_by_id` bigint NOT NULL,
  `finalized_at` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  `reconciliation_snapshot` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_pay_runs_on_company_id_and_period` (`company_id`,`period`),
  UNIQUE KEY `index_pay_runs_on_company_id_and_id` (`company_id`,`id`),
  KEY `index_pay_runs_on_created_by_id` (`created_by_id`),
  KEY `index_pay_runs_on_company_id` (`company_id`),
  KEY `fk_tenant_pay_runs_created_by_id` (`company_id`,`created_by_id`),
  CONSTRAINT `fk_rails_00e318e0e8` FOREIGN KEY (`created_by_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_50dfc9ef93` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_tenant_pay_runs_created_by_id` FOREIGN KEY (`company_id`, `created_by_id`) REFERENCES `users` (`company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `payroll_export_accesses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_export_accesses` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `payroll_export_id` bigint NOT NULL,
  `actor_id` bigint NOT NULL,
  `result` varchar(30) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_payroll_export_accesses_on_company_id` (`company_id`),
  KEY `export_access_history` (`company_id`,`payroll_export_id`,`id`),
  KEY `access_company_actor` (`company_id`,`actor_id`),
  CONSTRAINT `access_company_actor` FOREIGN KEY (`company_id`, `actor_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `access_company_export` FOREIGN KEY (`company_id`, `payroll_export_id`) REFERENCES `payroll_exports` (`company_id`, `id`),
  CONSTRAINT `fk_rails_61f8622ff0` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `export_access_result` CHECK ((`result` in (_utf8mb4'allowed',_utf8mb4'integrity_failed')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `payroll_exports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `payroll_exports` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `pay_run_id` bigint NOT NULL,
  `created_by_id` bigint NOT NULL,
  `public_id` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `period` date NOT NULL,
  `format` varchar(40) NOT NULL DEFAULT 'payroll_csv_v1',
  `version` int NOT NULL DEFAULT '1',
  `employee_count` int NOT NULL,
  `byte_size` int NOT NULL,
  `checksum` varchar(64) NOT NULL,
  `artifact` mediumtext NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_payroll_exports_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_payroll_exports_on_company_id_and_pay_run_id` (`company_id`,`pay_run_id`),
  UNIQUE KEY `index_payroll_exports_on_public_id` (`public_id`),
  KEY `index_payroll_exports_on_company_id` (`company_id`),
  KEY `index_payroll_exports_on_company_id_and_period_and_id` (`company_id`,`period`,`id`),
  KEY `export_company_creator` (`company_id`,`created_by_id`),
  CONSTRAINT `export_company_creator` FOREIGN KEY (`company_id`, `created_by_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `export_company_pay_run` FOREIGN KEY (`company_id`, `pay_run_id`) REFERENCES `pay_runs` (`company_id`, `id`),
  CONSTRAINT `fk_rails_83979df7e7` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `payroll_export_bounds` CHECK (((`version` = 1) and (`format` = _utf8mb4'payroll_csv_v1') and (`employee_count` between 1 and 2000) and (`byte_size` between 1 and 1048576)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `payslips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `payslips` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `pay_run_id` bigint NOT NULL,
  `employee_id` bigint NOT NULL,
  `gross_cents` bigint NOT NULL,
  `deductions_cents` bigint NOT NULL DEFAULT '0',
  `net_cents` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  `employee_code_snapshot` varchar(255) DEFAULT NULL,
  `employee_name_snapshot` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_payslips_on_pay_run_id_and_employee_id` (`pay_run_id`,`employee_id`),
  KEY `index_payslips_on_employee_id` (`employee_id`),
  KEY `index_payslips_on_pay_run_id` (`pay_run_id`),
  KEY `index_payslips_on_company_id` (`company_id`),
  KEY `fk_tenant_payslips_employee_id` (`company_id`,`employee_id`),
  KEY `fk_tenant_payslips_pay_run_id` (`company_id`,`pay_run_id`),
  CONSTRAINT `fk_rails_3984a17ec2` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_rails_c0e66eeaff` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`),
  CONSTRAINT `fk_rails_e593981ab1` FOREIGN KEY (`pay_run_id`) REFERENCES `pay_runs` (`id`),
  CONSTRAINT `fk_tenant_payslips_employee_id` FOREIGN KEY (`company_id`, `employee_id`) REFERENCES `employees` (`company_id`, `id`),
  CONSTRAINT `fk_tenant_payslips_pay_run_id` FOREIGN KEY (`company_id`, `pay_run_id`) REFERENCES `pay_runs` (`company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `key` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_permissions_on_key` (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `purchase_request_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `purchase_request_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `purchase_request_id` bigint NOT NULL,
  `actor_id` bigint NOT NULL,
  `version` int NOT NULL,
  `action` varchar(20) NOT NULL,
  `from_status` varchar(20) DEFAULT NULL,
  `to_status` varchar(20) NOT NULL,
  `note` text,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `purchase_event_version` (`purchase_request_id`,`version`),
  KEY `purchase_event_company_source` (`company_id`,`purchase_request_id`),
  KEY `purchase_event_actor_company` (`company_id`,`actor_id`),
  CONSTRAINT `purchase_event_actor_company` FOREIGN KEY (`company_id`, `actor_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `purchase_event_company_source` FOREIGN KEY (`company_id`, `purchase_request_id`) REFERENCES `purchase_requests` (`company_id`, `id`),
  CONSTRAINT `purchase_event_transition` CHECK (((`version` >= 0) and (((`action` = _utf8mb4'created') and (`from_status` is null) and (`to_status` = _utf8mb4'draft')) or ((`action` = _utf8mb4'updated') and (`from_status` = _utf8mb4'draft') and (`to_status` = _utf8mb4'draft')) or ((`action` = _utf8mb4'submitted') and (`from_status` = _utf8mb4'draft') and (`to_status` = _utf8mb4'submitted')) or ((`action` = _utf8mb4'approved') and (`from_status` = _utf8mb4'submitted') and (`to_status` = _utf8mb4'approved')) or ((`action` = _utf8mb4'rejected') and (`from_status` = _utf8mb4'submitted') and (`to_status` = _utf8mb4'rejected')))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `purchase_request_lines`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `purchase_request_lines` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `purchase_request_id` bigint NOT NULL,
  `position` int NOT NULL,
  `description` varchar(500) NOT NULL,
  `unit` varchar(30) NOT NULL,
  `quantity` decimal(9,3) NOT NULL,
  `estimated_unit_price` decimal(12,0) NOT NULL,
  `line_total` decimal(18,0) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `purchase_line_position` (`purchase_request_id`,`position`),
  KEY `purchase_line_company_source` (`company_id`,`purchase_request_id`),
  CONSTRAINT `purchase_line_company_source` FOREIGN KEY (`company_id`, `purchase_request_id`) REFERENCES `purchase_requests` (`company_id`, `id`) ON DELETE CASCADE,
  CONSTRAINT `purchase_line_amount` CHECK (((`quantity` > 0) and (`estimated_unit_price` >= 0) and (`line_total` = round((`quantity` * `estimated_unit_price`),0)) and (`position` between 1 and 50)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `procurement_line_insert_guard` BEFORE INSERT ON `purchase_request_lines` FOR EACH ROW BEGIN DECLARE parent_status VARCHAR(20); SELECT status INTO parent_status FROM purchase_requests WHERE id=NEW.purchase_request_id AND company_id=NEW.company_id FOR UPDATE; IF parent_status IS NULL OR parent_status<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase lines are immutable'; END IF; END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `procurement_line_update_guard` BEFORE UPDATE ON `purchase_request_lines` FOR EACH ROW BEGIN DECLARE parent_status VARCHAR(20); IF NEW.company_id<>OLD.company_id OR NEW.purchase_request_id<>OLD.purchase_request_id OR NEW.position<>OLD.position THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase line identity is immutable'; END IF; SELECT status INTO parent_status FROM purchase_requests WHERE id=OLD.purchase_request_id AND company_id=OLD.company_id FOR UPDATE; IF parent_status IS NULL OR parent_status<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase lines are immutable'; END IF; END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `procurement_line_delete_guard` BEFORE DELETE ON `purchase_request_lines` FOR EACH ROW BEGIN DECLARE parent_status VARCHAR(20); SELECT status INTO parent_status FROM purchase_requests WHERE id=OLD.purchase_request_id AND company_id=OLD.company_id FOR UPDATE; IF parent_status IS NULL OR parent_status<>'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase lines are immutable'; END IF; END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `purchase_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `purchase_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `created_by_id` bigint NOT NULL,
  `reviewed_by_id` bigint DEFAULT NULL,
  `code` varchar(32) NOT NULL,
  `title` varchar(200) NOT NULL,
  `purpose` text NOT NULL,
  `needed_on` date NOT NULL,
  `currency` varchar(3) NOT NULL DEFAULT 'VND',
  `estimated_total` decimal(18,0) NOT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'draft',
  `submitted_at` datetime(6) DEFAULT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `rejection_reason` text,
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `purchase_request_company_identity` (`company_id`,`id`),
  UNIQUE KEY `purchase_request_company_code` (`company_id`,`code`),
  KEY `index_purchase_requests_on_company_id` (`company_id`),
  KEY `purchase_request_queue` (`company_id`,`status`,`created_by_id`,`id`),
  KEY `purchase_request_creator_company` (`company_id`,`created_by_id`),
  KEY `purchase_request_reviewer_company` (`company_id`,`reviewed_by_id`),
  CONSTRAINT `fk_rails_fd8a61ba25` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `purchase_request_creator_company` FOREIGN KEY (`company_id`, `created_by_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `purchase_request_reviewer_company` FOREIGN KEY (`company_id`, `reviewed_by_id`) REFERENCES `users` (`company_id`, `id`),
  CONSTRAINT `purchase_request_chronology` CHECK (((`reviewed_at` is null) or (`reviewed_at` >= `submitted_at`))),
  CONSTRAINT `purchase_request_maker_checker` CHECK (((`reviewed_by_id` is null) or (`reviewed_by_id` <> `created_by_id`))),
  CONSTRAINT `purchase_request_money` CHECK (((`currency` = _utf8mb4'VND') and (`estimated_total` >= 0))),
  CONSTRAINT `purchase_request_state` CHECK ((((`status` = _utf8mb4'draft') and (`submitted_at` is null) and (`reviewed_at` is null) and (`reviewed_by_id` is null) and (`rejection_reason` is null)) or ((`status` = _utf8mb4'submitted') and (`submitted_at` is not null) and (`reviewed_at` is null) and (`reviewed_by_id` is null) and (`rejection_reason` is null)) or ((`status` = _utf8mb4'approved') and (`submitted_at` is not null) and (`reviewed_at` is not null) and (`reviewed_by_id` is not null) and (`rejection_reason` is null)) or ((`status` = _utf8mb4'rejected') and (`submitted_at` is not null) and (`reviewed_at` is not null) and (`reviewed_by_id` is not null) and (`rejection_reason` is not null))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `procurement_request_insert_guard` BEFORE INSERT ON `purchase_requests` FOR EACH ROW BEGIN IF NEW.status <> 'draft' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase requests start as draft'; END IF; END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `procurement_request_update_guard` BEFORE UPDATE ON `purchase_requests` FOR EACH ROW BEGIN DECLARE item_count INT; DECLARE item_total DECIMAL(20,0); IF NEW.company_id<>OLD.company_id OR NEW.created_by_id<>OLD.created_by_id OR NEW.code<>OLD.code OR NEW.currency<>OLD.currency THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase identity is immutable'; END IF; IF OLD.status<>'draft' AND (NOT(NEW.title<=>OLD.title) OR NOT(NEW.purpose<=>OLD.purpose) OR NOT(NEW.needed_on<=>OLD.needed_on) OR NOT(NEW.estimated_total<=>OLD.estimated_total)) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Submitted purchase content is immutable'; END IF; IF NOT((OLD.status='draft' AND NEW.status IN ('draft','submitted')) OR (OLD.status='submitted' AND NEW.status IN ('approved','rejected'))) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid purchase transition'; END IF; IF NEW.status='submitted' THEN SELECT COUNT(*),COALESCE(SUM(line_total),0) INTO item_count,item_total FROM purchase_request_lines WHERE purchase_request_id=OLD.id AND company_id=OLD.company_id FOR UPDATE; IF item_count<1 OR item_count>50 OR item_total<>NEW.estimated_total THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Purchase total does not match lines'; END IF; END IF; END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `role_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `role_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_role_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_role_permission_unique` (`company_role_id`,`permission_id`),
  KEY `index_role_permissions_on_company_role_id` (`company_role_id`),
  KEY `index_role_permissions_on_permission_id` (`permission_id`),
  CONSTRAINT `fk_rails_439e640a3f` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`),
  CONSTRAINT `fk_rails_5a93aacc02` FOREIGN KEY (`company_role_id`) REFERENCES `company_roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `system_audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `system_audit_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `principal_user_id` bigint NOT NULL,
  `company_id` bigint NOT NULL,
  `action` varchar(60) NOT NULL,
  `record_type` varchar(40) NOT NULL,
  `record_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_system_audit_logs_on_principal_user_id` (`principal_user_id`),
  KEY `index_system_audit_logs_on_company_id` (`company_id`),
  KEY `index_system_audit_logs_on_company_id_and_id` (`company_id`,`id`),
  CONSTRAINT `fk_rails_79476bbcbc` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_rails_8758f7a91c` FOREIGN KEY (`principal_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `system_grants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `system_grants` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_system_grants_on_user_id_and_permission_id` (`user_id`,`permission_id`),
  KEY `index_system_grants_on_user_id` (`user_id`),
  KEY `index_system_grants_on_permission_id` (`permission_id`),
  CONSTRAINT `fk_rails_00bcf19bd6` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`),
  CONSTRAINT `fk_rails_6b14276886` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `permission_id` bigint NOT NULL,
  `granted` tinyint(1) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_user_permissions_on_user_id_and_permission_id` (`user_id`,`permission_id`),
  KEY `index_user_permissions_on_user_id` (`user_id`),
  KEY `index_user_permissions_on_permission_id` (`permission_id`),
  CONSTRAINT `fk_rails_b29e483ce4` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_e2cb0687d2` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `password_digest` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `role` varchar(255) NOT NULL DEFAULT 'employee',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `company_id` bigint NOT NULL,
  `principal_user_id` bigint DEFAULT NULL,
  `login_email` varchar(255) GENERATED ALWAYS AS ((case when (`principal_user_id` is null) then `email` else NULL end)) STORED,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_users_on_company_id_and_id` (`company_id`,`id`),
  UNIQUE KEY `index_users_on_company_id_and_email` (`company_id`,`email`),
  UNIQUE KEY `principal_company_membership` (`principal_user_id`,`company_id`),
  UNIQUE KEY `index_users_on_login_email` (`login_email`),
  KEY `index_users_on_company_id` (`company_id`),
  KEY `fk_users_company_role` (`company_id`,`role`),
  CONSTRAINT `fk_rails_7682a3bdfe` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `fk_users_company_role` FOREIGN KEY (`company_id`, `role`) REFERENCES `company_roles` (`company_id`, `key`),
  CONSTRAINT `membership_principal` FOREIGN KEY (`principal_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `principal_owns_credentials` CHECK ((((`principal_user_id` is null) and (`password_digest` is not null)) or ((`principal_user_id` is not null) and (`password_digest` is null))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `users_membership_insert_guard` AFTER INSERT ON `users` FOR EACH ROW BEGIN
  IF NEW.principal_user_id IS NOT NULL THEN
    IF NEW.principal_user_id = NEW.id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'membership must not reference itself';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users p WHERE p.id = NEW.principal_user_id AND p.principal_user_id IS NULL AND p.company_id <> NEW.company_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'membership requires a root identity in another company';
    END IF;
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,NO_AUTO_VALUE_ON_ZERO,STRICT_TRANS_TABLES,STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 */ /*!50003 TRIGGER `users_membership_update_guard` BEFORE UPDATE ON `users` FOR EACH ROW BEGIN
  IF NEW.id <> OLD.id OR NOT (NEW.principal_user_id <=> OLD.principal_user_id) OR NEW.company_id <> OLD.company_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'identity and company are immutable; create a membership';
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `work_shifts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `work_shifts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `company_id` bigint NOT NULL,
  `code` varchar(30) NOT NULL,
  `name` varchar(255) NOT NULL,
  `start_minute` int NOT NULL,
  `end_minute` int NOT NULL,
  `unpaid_break_minutes` int NOT NULL DEFAULT '0',
  `grace_in_minutes` int NOT NULL DEFAULT '0',
  `grace_out_minutes` int NOT NULL DEFAULT '0',
  `overtime_threshold_minutes` int NOT NULL DEFAULT '0',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `lock_version` int NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_work_shifts_on_company_id_and_code` (`company_id`,`code`),
  UNIQUE KEY `index_work_shifts_on_company_id_and_id` (`company_id`,`id`),
  KEY `index_work_shifts_on_company_id` (`company_id`),
  CONSTRAINT `fk_rails_fc6c0bb3a3` FOREIGN KEY (`company_id`) REFERENCES `companies` (`id`),
  CONSTRAINT `shift_clock_range` CHECK (((`start_minute` between 0 and 1439) and (`end_minute` between 0 and 1439) and (`start_minute` <> `end_minute`))),
  CONSTRAINT `shift_rule_range` CHECK (((`unpaid_break_minutes` >= 0) and (`unpaid_break_minutes` < (case when (`end_minute` > `start_minute`) then (`end_minute` - `start_minute`) else ((`end_minute` + 1440) - `start_minute`) end)) and (`grace_in_minutes` between 0 and (case when (`end_minute` > `start_minute`) then (`end_minute` - `start_minute`) else ((`end_minute` + 1440) - `start_minute`) end)) and (`grace_out_minutes` between 0 and (case when (`end_minute` > `start_minute`) then (`end_minute` - `start_minute`) else ((`end_minute` + 1440) - `start_minute`) end)) and (`overtime_threshold_minutes` between 0 and (case when (`end_minute` > `start_minute`) then (`end_minute` - `start_minute`) else ((`end_minute` + 1440) - `start_minute`) end))))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;
INSERT INTO `schema_migrations` (version) VALUES
('20261113000001'),
('20261112000009'),
('20261112000008'),
('20261112000007'),
('20261112000006'),
('20261112000005'),
('20261112000004'),
('20261112000003'),
('20261112000002'),
('20261112000001'),
('20261111000005'),
('20261111000004'),
('20261111000003'),
('20261111000002'),
('20261111000001'),
('20261028000002'),
('20261028000001'),
('20261025000001');
