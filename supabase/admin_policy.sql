-- schema.sql을 먼저 실행한 뒤, SQL Editor에서 이어서 실행하세요.
-- 로그인한 관리자 계정만 신청 데이터를 조회할 수 있도록 하는 정책입니다.
-- (참여신청 폼을 채우는 방문자는 그대로 "입력만 가능"하고, 조회는 여전히 불가능합니다.)

create policy "authenticated can view applications"
  on public.applications
  for select
  to authenticated
  using (true);
