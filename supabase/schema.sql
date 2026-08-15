-- Supabase SQL 편집기(SQL Editor)에서 그대로 실행하세요.
-- 참여신청 폼(2026 SH 마곡일반산업단지 매각설명회)을 저장할 테이블과,
-- 익명 사용자는 "입력만 가능, 조회는 불가능"하도록 하는 보안 정책(RLS)을 함께 생성합니다.
--
-- 이미 이 테이블이 있는 상태(예전 헤드카운트/관심분야 스키마)에서 새 설문으로 바꾸는 경우에는
-- 이 파일을 다시 실행하지 말고 migration_2026_apply_form.sql만 실행하세요.

create extension if not exists pgcrypto;

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  company text not null,
  department text,
  manager_name text not null,
  "position" text,
  phone text not null,
  email text not null,
  companions jsonb not null default '[]'::jsonb,
  interested_site text,
  privacy_consent boolean not null default false,
  marketing_consent boolean not null default false
);

alter table public.applications enable row level security;

-- 익명(anon) 키로 접수는 가능하지만, 조회/수정/삭제는 불가능하도록 제한합니다.
-- (조회는 admin_policy.sql의 비밀번호 기반 함수로, 삭제는 migration_2026_apply_form.sql의
-- 비밀번호 기반 함수로만 가능합니다.)
create policy "anon can insert applications"
  on public.applications
  for insert
  to anon
  with check (true);
