# Happy Dollar — 로그인/회원가입 + 관리자 수동 승인 설정 가이드

이메일+비밀번호로 로그인/회원가입하고, **이용 승인은 관리자(당신)가
Supabase 화면에서 직접** 해주는 방식입니다. 결제대행사(토스 등) 연동이
필요 없습니다.

## 전체 흐름

1. 손님이 앱에 접속 → 이메일/비밀번호로 **회원가입**
2. 로그인하면 "아직 승인되지 않았습니다" 화면과 함께 입금 계좌 안내가 뜸
3. 손님이 연락처(+입금자명, 다를 경우) 입력 후 **"입금 완료, 승인 요청하기"** 클릭
   → 이 시점엔 아직 상태가 안 바뀝니다, 관리자에게 "요청이 왔다"는 표시만 남음
4. 당신이 실제 입금 확인
5. Supabase 대시보드에서 그 사람 행을 찾아 **승인(active)** 처리
6. 손님이 "승인됐는지 다시 확인하기" 버튼을 누르거나 다시 로그인하면 바로 앱이 열림

## 1단계. Supabase 프로젝트 만들기 (5분, 무료)

1. https://supabase.com → 회원가입 → "New Project"
2. 이름(예: happy-dollar), 비밀번호, 리전은 **Northeast Asia (Seoul)** 선택
3. 왼쪽 메뉴 **SQL Editor** → 이 폴더의 `schema.sql` 내용을 전부 복사해서
   붙여넣고 **Run**
4. 왼쪽 메뉴 **Project Settings → API** 에서 복사:
   - `Project URL`
   - `anon public` 키

## 2단계. 이메일 인증 설정 (선택)

기본적으로 회원가입하면 확인 이메일이 발송됩니다. 테스트 단계에서
매번 이메일 인증하기 번거로우면:
Supabase 대시보드 → **Authentication → Providers → Email** →
"Confirm email" 옵션을 꺼두면 가입 즉시 로그인 가능합니다.
(실제 서비스 오픈 시에는 다시 켜는 걸 권장합니다.)

## 3단계. index.html에 정보 입력

`index.html`에서 아래 부분을 실제 값으로 바꿉니다.

```js
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-SUPABASE-ANON-KEY';
const BANK_INFO = {
  bankName: 'OO은행',
  bankAccount: '000-000000-00-000',
  bankHolder: '홍길동',
  amount: 99000,
};
```

## 4단계. 배포

이전과 동일하게 압축 풀어서 Netlify Drop 또는 GitHub Pages에 올립니다.

## 5단계. 승인하는 방법

**Table Editor에서 클릭 몇 번 (가장 쉬움)**

1. Supabase 대시보드 → **Table Editor** → `profiles` 테이블
2. `status`가 `pending`이고 `requested_at`이 채워진 행 중 입금 확인된
   사람을 찾습니다 (email, name, phone, depositor_name으로 구분)
3. 그 행의 `status`를 `active`로 바꾸고 저장

**여러 건을 한 번에 보고 싶으면 — SQL Editor**

```sql
-- 승인 대기 중인 요청 전체 보기
select email, name, phone, depositor_name, amount, requested_at
from profiles where status = 'pending' and requested_at is not null
order by requested_at desc;

-- 이메일로 찾아 승인
update profiles set status = 'active', approved_at = now()
where email = '고객이메일@example.com';
```

## 자주 묻는 것들

**Q. 아직 입금도 안 했는데 회원가입만 한 사람들도 다 보이나요?**
네, `profiles`에는 가입한 모든 사람이 `status='pending'`으로 보입니다.
`requested_at`이 채워진 사람만 "입금했다고 알려온 사람"입니다. 이 값이
비어있으면 아직 입금 요청 버튼도 안 누른 상태라는 뜻이에요.

**Q. 무료 체험 계정을 만들어주고 싶어요.**
해당 사용자가 가입한 뒤, `profiles` 테이블에서 그 사람 행의 `status`를
바로 `active`로 바꿔주면 됩니다. 입금 없이도 이용 가능해집니다.

**Q. 이용을 중지시키고 싶어요.**
`status`를 `revoked`로 바꾸면, 다음 로그인 시 다시 승인 대기 화면이
뜨고 이용할 수 없습니다.

**Q. 비밀번호를 잊어버렸다는 사람이 있어요.**
Supabase 대시보드 → Authentication → Users 에서 해당 사용자를 찾아
비밀번호 재설정 메일을 보낼 수 있습니다.

## 아직 없는 것 (실제 판매 전에 준비하시면 좋은 것)

- 이용약관 / 환불 정책 페이지
- 개인정보처리방침 (이메일·이름·연락처를 수집하므로 필요)
- 보험업 관련 법적 검토 (적합성진단서 서식, 전자서명 유효성 등)
