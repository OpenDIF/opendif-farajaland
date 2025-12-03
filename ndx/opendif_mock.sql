--
-- PostgreSQL database dump
--

-- \restrict command removed for compatibility

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
-- SET transaction_timeout = 0;  -- Commented out: PostgreSQL 17+ only, not supported in PostgreSQL 15
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: members; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.members (member_id, name, email, phone_number, created_at, updated_at, idp_user_id) FROM stdin;
mem_4e3ef278-5850-4bef-9f1b-4e41766999ec	Registrar General's Department	rgd@ndx.gov.lk	+940112234567	2025-10-01 12:23:50.06+00	2025-10-01 12:23:52.879+00	4e3ef278-5850-4bef-9f1b-4e41766999ec
mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	Department for Registration of Persons	drp@ndx.gov.lk	+940113985890	2025-10-02 16:19:29.138385+00	2025-10-08 09:38:31.592445+00	0e3057ad-b110-4696-bdbf-fab6c5189343
mem_cc93641c-b357-4b19-bcfd-13c497d710d7	Department of Immigration & Emigration	die@ndx.gov.lk	+940113985890	2025-10-07 16:46:52.590874+00	2025-10-22 17:09:10.797397+00	ff0c95f4-233d-449a-97e5-536e15af1847
mem_47578e70-2a1b-417c-b5f0-cb7819c59817	ORG 1	sthanikan2000@gmail.com	+940113985890	2025-10-30 06:03:37.499741+00	2025-10-30 06:03:37.499741+00	fadebe20-b5db-4593-adec-99b9518746c0
\.


--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.applications (application_id, application_name, application_description, version, created_at, updated_at, selected_fields, member_id) FROM stdin;
passport-app	Passport Application Web App	\N	active	2025-11-01 12:52:46.808564+00	2025-11-01 12:52:46.808564+00	[{"schemaId": "abc-212", "fieldName": "getPersonInfo.birthDate"}, {"schemaId": "drp-schema-v1", "fieldName": "person.permanentAddress"}, {"schemaId": "drp-schema-v1", "fieldName": "person.fullName"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.name"}, {"schemaId": "drp-schema-v1", "fieldName": "person.otherNames"}, {"schemaId": "drp-schema-v1", "fieldName": "person.profession"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.sex"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.brNo"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.birthPlace"}, {"schemaId": "abc-212", "fieldName": "getPersonInfo.district"}]	mem_cc93641c-b357-4b19-bcfd-13c497d710d7
\.


--
-- Data for Name: application_submissions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.application_submissions (submission_id, previous_application_id, application_name, application_description, status, created_at, updated_at, review, member_id, selected_fields) FROM stdin;
sub_1a3f54ee-39c8-4c5e-ba11-efa5be29e48f	\N	Test App		pending	2025-10-31 13:01:57.301412+00	2025-10-31 13:23:28.768317+00	\N	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	[{"schemaId": "drp-schema-v1", "fieldName": "personInfo.fullName"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.make"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.class.className"}, {"schemaId": "dmt-schema-v1", "fieldName": "vehicle.class.classCode"}]
\.


--
-- Data for Name: schemas; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schemas (schema_id, schema_name, sdl, endpoint, version, schema_description, created_at, updated_at, member_id, auth_type, api_key_name, api_key_value, client_id, client_secret, token_url, refresh_token_url) FROM stdin;
abc-212	RGD Schema	"Date (isoformat)"\nscalar Date\n\ntype Father {\n  name: String!\n  nic: String!\n  birthDate: Date!\n  birthPlace: String!\n  race: String!\n}\n\ntype Informant {\n  signature: String!\n  fullName: String!\n  residence: String!\n  relationshipToBaby: String!\n  nic: String!\n}\n\ntype Mother {\n  name: String!\n  nic: String!\n  birthDate: Date!\n  birthPlace: String!\n  race: String!\n  ageAtBirth: Int!\n}\n\ntype PersonData {\n  id: Int!\n  brNo: String!\n  nic: ID!\n  district: String!\n  division: String!\n  birthDate: Date!\n  birthPlace: String!\n  name: String!\n  sex: String!\n  areParentsMarried: Boolean!\n  isGrandfatherBornInSriLanka: Boolean!\n  father: Father!\n  mother: Mother!\n  dateOfRegistration: Date!\n  registrarSignature: String!\n  informant: Informant!\n}\n\ntype Query {\n  "Get person information by NIC"\n  healthCheck: String!\n  "Get person information by NIC"\n  getPersonInfo(nic: ID!): PersonData\n}	http://test.com	active	Test Schema	2025-10-16 02:17:32.4963+00	2025-10-16 02:17:32.4963+00	mem_4e3ef278-5850-4bef-9f1b-4e41766999ec	oauth2	\N	\N	2oIRGWpHDjmTPqDo8tOJCu2DwANp	xJclnZNorKGwLJPpKQRAtqK1ZtJh	https://41200aa1-4106-4e6c-babf-311dce37c04a-dev.e1-us-east-azure.choreosts.dev/oauth2/token	\N
drp-schema-v1	DRP Schema	scalar ID\nscalar String\nscalar Boolean\n\ntype PersonData {\n  nic: ID!\n  fullName: String!\n  otherNames: String!\n  permanentAddress: String!\n  profession: String!\n  photo: String!\n}\n\ntype Query {\n  person(nic: ID!): PersonData\n}	https://41200aa1-4106-4e6c-babf-311dce37c04a-dev.e1-us-east-azure.choreoapis.dev/drp-provider/drp-adapter/v2	active	Test Schema	2025-10-16 02:17:32.4963+00	2025-10-16 02:17:32.4963+00	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7	api_key	Choreo-API-Key	chk_eyJjb25uZWN0aW9uLWlkIjoiMDFmMGFiMWMtMDZjYy0xYmJlLWE1MTUtODU1ZTA5NzEwMWNmIiwia2V5Ijoiajg3cDQ0MGFxNHFiZ3g2aWJuMjJrYW4zcGNnbmZ5cHp2NnR6M3Z2dmt6cGZlcjVmMDQ5byJ9cZY3Ew	\N	\N	\N	\N
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.audit_logs (id, "timestamp", status, requested_data, application_id, schema_id, consumer_id, provider_id) FROM stdin;
dfcd576f-cf45-40ce-aca1-c5cd02250983	2025-10-21 03:29:02.811146+00	success	query { testQuery }	passport-app	abc-212	\N	\N
295dabf3-22b5-4460-ba00-d42efeb1e811	2025-10-21 03:32:10.137349+00	failure	query { testWithValidIds }	passport-app	abc-212	\N	\N
44e297bf-3166-4f5f-ace2-13cb76106359	2025-10-21 03:33:22.697695+00	success	{"query": "query { testUpdatedMiddleware }"}	passport-app	drp-schema-v1	\N	\N
\.


--
-- Data for Name: consent_records; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.consent_records (consent_id, owner_id, owner_email, app_id, status, type, created_at, updated_at, expires_at, grant_duration, fields, session_id, consent_portal_url, updated_by) FROM stdin;
consent_10b3a51a	test@opensource.lk	test@opensource.lk	passport-app	pending	realtime	2025-11-03 03:43:09.181518+00	2025-11-03 03:47:56.611375+00	2025-11-03 04:47:56.611375+00	PT1H	{personInfo.permanentAddress,personInfo.fullName,personInfo.nic,personInfo.hello}	session_123	https://64de011b-df46-423d-8e33-814b5cc60339.e1-us-east-azure.choreoapps.dev/?consent_id=consent_10b3a51a	test@opensource.lk
consent_50372597	hello@opensource.lk	hello@opensource.lk	passport-app	pending	realtime	2025-11-03 03:48:07.883343+00	2025-11-03 03:48:07.883343+00	2025-11-03 04:48:07.883343+00	PT1H	{personInfo.permanentAddress,personInfo.fullName,personInfo.nic,personInfo.hello}	session_123	https://64de011b-df46-423d-8e33-814b5cc60339.e1-us-east-azure.choreoapps.dev/?consent_id=consent_50372597	hello@opensource.lk
consent_85ae2544	admin@ndx.gov.lk	admin@ndx.gov.lk	passport-app	pending	realtime	2025-11-03 04:09:53.660416+00	2025-11-03 04:09:53.660416+00	2025-11-03 05:09:53.660416+00	1h	{getPersonInfo.name,person.fullName,person.otherNames,person.profession,person.permanentAddress,getPersonInfo.birthDate,getPersonInfo.sex,getPersonInfo.brNo,getPersonInfo.district,getPersonInfo.birthPlace}	session_123	https://64de011b-df46-423d-8e33-814b5cc60339.e1-us-east-azure.choreoapps.dev/?consent_id=consent_85ae2544	admin@ndx.gov.lk
consent_abe08d1d	mohamed@opensource.lk	mohamed@opensource.lk	passport-app	pending	realtime	2025-11-13 08:13:58.936596+00	2025-11-13 08:13:58.936596+00	2025-11-13 09:13:58.936596+00	1h	{getPersonInfo.birthDate,person.permanentAddress}		https://64de011b-df46-423d-8e33-814b5cc60339.e1-us-east-azure.choreoapps.dev/?consent_id=consent_abe08d1d	mohamed@opensource.lk
\.


--
-- Data for Name: policy_metadata; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.policy_metadata (id, schema_id, field_name, display_name, description, source, is_owner, access_control_type, allow_list, created_at, updated_at, owner) FROM stdin;
488e0205-3949-4460-b3d2-5403d2b82ea6	drp-schema-v1	person.permanentAddress	Residing Address	Person's Residential Address	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
ae05f09b-432e-4473-8da1-9633c3da9c72	abc-212	getPersonInfo.district	Birth District of Person	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
2cf4f41f-7934-4a49-9a03-9f851f395436	abc-212	getPersonInfo.birthPlace	Birth Place of Person	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
5719f279-ee92-4536-9e0b-5443aa064cf8	abc-212	getPersonInfo.brNo	Birth Registration Number	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
171584a4-36ed-4989-a8cf-da292d908bb6	abc-212	getPersonInfo.birthDate	Birth Date	Person's Birth Date	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
8180a601-b67d-400b-8528-012797d9d6d8	abc-212	getPersonInfo.sex	Person's Sex	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
10d4da3e-8d7d-42bb-97ca-30429ef895cd	drp-schema-v1	person.profession	Your Profession	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:10:48.459932+00	2025-10-30 04:10:48.459932+00	citizen
8c07811e-6573-4826-bcb3-8f36a52bb810	drp-schema-v1	person.otherNames	Person's Other Names	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2025-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:10:48.459932+00	2025-10-30 04:10:48.459932+00	citizen
96c4cce8-5a0a-42cb-9698-910c4ec45305	abc-212	getPersonInfo.name	Person's Name	\N	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-30 04:07:00.056146+00	2025-10-30 04:07:00.056146+00	citizen
d45c4b6c-8bbd-4ee8-9acd-0b71015aaeb9	drp-schema-v1	person.fullName	Full Name	Person's Full Name	primary	f	restricted	{"passport-app": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}, "7a16e556-70a1-4014-8ec1-9397a5212fee": {"expires_at": "2026-11-25T14:26:01.382878+05:30", "updated_at": "2025-10-25T14:26:01.382879+05:30"}}	2025-10-28 14:01:48.915218+00	2025-10-28 14:01:48.915218+00	citizen
\.


--
-- Data for Name: schema_submissions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schema_submissions (submission_id, previous_schema_id, schema_name, schema_description, sdl, schema_endpoint, status, created_at, updated_at, review, member_id) FROM stdin;
sub_fe507219-5f41-4485-aedf-407e6827ac7b	\N	Person Information		directive @accessControl(type: String) on FIELD_DEFINITION\n\ndirective @source(value: String) on FIELD_DEFINITION\n\ndirective @isOwner(value: Boolean) on FIELD_DEFINITION\n\ndirective @owner(value: String) on FIELD_DEFINITION\n\ndirective @description(value: String) on FIELD_DEFINITION\n\ntype BirthInfo {\n  birthCertificateID: ID! @accessControl(type: "public") @source(value: "primary") @isOwner(value: true)\n  birthPlace: String! @accessControl(type: "restricted") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n  birthDate: String! @accessControl(type: "restricted") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n}\n\ntype User {\n  id: ID! @accessControl(type: "public") @source(value: "primary") @isOwner(value: true)\n  name: String! @accessControl(type: "public") @source(value: "primary") @isOwner(value: false) @owner(value: "citizen")\n  email: String! @accessControl(type: "restricted") @source(value: "fallback")\n  birthInfo: BirthInfo @description(value: "Default Description")\n}\n\ntype Query {\n  getUser(id: ID!): User @description(value: "Default Description")\n  getBirthInfo(userId: ID!): BirthInfo @description(value: "Default Description")\n}	https://abvdsfkj.jbdavsvjkhb	pending	2025-10-30 16:48:31.746275+00	2025-10-30 16:48:31.746275+00	\N	mem_bbe7774f-f3c2-4a7a-8c34-d6d57506d3d7
\.


--
-- Data for Name: schema_versions; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.schema_versions (id, from_version, to_version, change_type, changes, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: unified_schemas; Type: TABLE DATA; Schema: public; Owner: exchange
--

COPY public.unified_schemas (id, version, sdl, status, description, created_at, updated_at, created_by, checksum, is_active) FROM stdin;
\.


--
-- Name: schema_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: exchange
--

SELECT pg_catalog.setval('public.schema_versions_id_seq', 1, false);


--
-- PostgreSQL database dump complete
--

\unrestrict yH2J1bgfBGYld2dvL8UgPxE537kpSjxeHuswoBExpLnSaCBpEDfRlZyAy0DYnRo

