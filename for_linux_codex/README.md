# for_linux_codex 쉬운 사용법

이 파일은 **노트북을 켜지 않고도** iPhone/Galaxy RisuAI에서 자기 ChatGPT/Codex 계정을 쓰기 위한 GCP용 패키지입니다.

흐름은 이렇습니다.

```text
폰 RisuAI
→ GCP 서버 주소
→ 내 ChatGPT/Codex 계정
```

## 0. 먼저 할 일

GCP VM의 SSH 창을 열고, 오른쪽 위 **파일 업로드**로 `for_linux_codex.zip`을 올립니다.

업로드가 끝난 뒤부터 아래 명령어를 SSH 창에 복사해서 넣으면 됩니다.

## 1. 압축 풀기

아래 전체를 복사해서 SSH 창에 붙여넣고 Enter를 누르세요.

```bash
sudo apt update
sudo apt install -y unzip
unzip for_linux_codex.zip
cd for_linux_codex
```

## 2. 설치하기

아래 명령어를 복사해서 SSH 창에 붙여넣고 Enter를 누르세요.

```bash
bash setup_user.sh
source ./env.sh
```

설치가 끝나면 다음 단계로 갑니다.

## 3. ChatGPT/Codex 로그인하기

아래 명령어를 실행하세요.

```bash
bash login.sh
```

그러면 SSH 창에 긴 주소가 뜹니다.

그 주소를 브라우저로 열고, **자기 ChatGPT/Codex 계정으로 로그인**하세요.

로그인이 끝나면 다시 SSH 창으로 돌아옵니다.

## 4. 서버 켜기

아래 명령어를 실행하세요.

```bash
bash start_detached.sh
```

그러면 비밀번호를 만들라고 나옵니다.

```text
Risu API password:
```

여기에 RisuAI에 넣을 비밀번호를 직접 정해서 입력하세요.

입력할 때 화면에 글자가 안 보이는 것은 정상입니다. 비밀번호를 입력하고 Enter를 누르면 됩니다.

## 5. 나온 주소 복사하기

성공하면 이런 정보가 뜹니다.

```text
base_url=https://어쩌구.trycloudflare.com
api_password=내가_방금_만든_비밀번호
format=Anthropic Claude
model=claude-3-opus
```

여기서 중요한 것은 두 개입니다.

```text
base_url
api_password
```

## 6. 폰 RisuAI에 넣기

iPhone/Galaxy RisuAI에서 Custom API 설정을 열고 이렇게 넣습니다.

```text
URL: base_url에 나온 https 주소
API password: 내가 만든 비밀번호
요청 모델: claude-3-opus
형식: Anthropic Claude
Tokenizer: Claude
Response streaming: 처음엔 끄기
Autofill Request URL: 끄기
```

먼저 `안녕`처럼 짧게 테스트하세요.

## 다시 켤 때

서버가 꺼졌거나 주소가 죽었으면 SSH에서 아래만 다시 실행하면 됩니다.

```bash
cd for_linux_codex
source ./env.sh
bash start_detached.sh
```

## 서버 끄기

```bash
cd for_linux_codex
bash stop.sh
```

## 주의

- 이 서버는 실행한 사람의 ChatGPT/Codex 계정을 사용합니다.
- `base_url`과 `API password`를 공개하지 마세요.
- GCP VM을 삭제하거나 중지하면 연결이 끊깁니다.
- GCP 설정에 따라 과금이 생길 수 있으니 예산 알림을 켜두는 것을 추천합니다.
