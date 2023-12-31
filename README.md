# dogArea : 우리 댕댕이 영역 표시하기

**TestFlight**
> [체험하기](https://testflight.apple.com/join/61E3OBmk)
<div align="left">
	<img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=white"/>
  <img src="https://img.shields.io/badge/OpenAI-412991?style=flat&logo=openai&logoColor=white"/>

## Idea : 강아지들이 산책 할 때 영역 표시를 하는데, 이걸 실제 지도 위에 표현해보자!

## 강아지들의 영역 표시

산책하다 보면 강아지들이 영역 표시를 하는 것을 아실 수 있습니다.

그런데 이 영역을 시각적으로 보고 기록할 수 있으면 재미있지 않겠습니까?

그래서 간단한 토이 프로젝트의 의미로 프로젝트를 시작하게 되었습니다.

### 사용하는 기능

1. Map > location의 배열을 가지고 영역 폴리곤을 만들어야 함!
   1. Mapkit 활용
   2. Location의 입력을 받아 버튼 눌렀을 때 annotation을 추가하고 완성된 annotatione들의 coordinate를 기반으로 폴리곤 제작
   3. 완성된 폴리곤을 토대로 image화 하여 저장, 사진 저장 기능 추가
2. Data storage
   1. CoreData로 활용
      1. Polygon 데이터 저장 : 역대 산책한 영역들을 저장
      2. 유저 정보 저장 : 유저의 identity와 강아지 관련 정보 저장
3. User에 대한 고민 : 프로필 이미지를 캐릭터화 하고 싶다..
   1. OpenAI로 image generate하기 < 바라는 이미지로는 안나옴,, 그냥 이미지 입력 받아야 할듯
   2. Apple 로그인을 통해 User 정보 확보하기
      1. 처음 사용자의 경우 프로필을 만드는 기능을 추가 > 완료
      2. 필요한 정보는 Identifiable한 랜덤 정보면 된다.
         1. 이메일, 이름으로 결정
      3. 사용자의 프로필 이미지의 필요 여부를 결정해야 한다.
         1. 없을 경우 empty image넣어주기로 결정
      4. 강아지의 정보를 필수값으로 저장해야 한다. 이름은 필수 이미지는 옵셔널
   3. 입력받은 UIImage를 URL화 하기
      1. Firebase storage를 활용해서 해결하였다.

## 화면

### 스플래시

- 로티 애니메이션을 추가

  <img src="https://p.ipic.vip/2pwx2f.gif" alt="스플래시"  width="200" height="432" />

### 홈

1. 메인 화면
   1. <img src="https://p.ipic.vip/47rvyp.png" alt="IMG_0357"  width="200" height="432" /><img src="https://p.ipic.vip/9cm520.png" alt="IMG_0358"  width="200" height="432" />
   2. 산책한 날에 강아지 아이콘을 추가하였습니다.
   3. 주별로(해당 주 일요일부터 토요일까지) 산책한 영역의 넓이와 산책 횟수를 산출하여 보여주었습니다.
   4. 누적된 산책 영역을 합산하여 대한민국 지자체 및 기타 유명한 지역의 넓이와 비교하여 보았습니다.
   5. 점차 넓은 영역을 넘어서도록 동기 부여용으로 제작하였습니다.
2. 더보기 눌렀을 때 뷰
   1. <img src="https://p.ipic.vip/ccc70a.png" alt="IMG_0359"  width="200" height="432" />
   2. 여태까지 정복한 영역을 최신순으로 정렬하여 보여줍니다.

#### Todo

-  막 산책을 마치고 다음 목표를 넘어섰을 때 Event를 추가하고 싶습니다.

### 산책 목록

1. 메인 뷰
   1. <img src="https://p.ipic.vip/md9o07.png" alt="IMG_0360"  width="200" height="432" /><img src="https://p.ipic.vip/3ttd2o.png" alt="IMG_0361"  width="200" height="432" />
      1. 산책 기록을 리스트로 보여줍니다.
      2. 셀 눌렀을 때는 영역을 지도에서 폴리곤으로 보여주고, 산책 정보를 보여주며, 사진으로 저장하는 기능을 추가하였습니다.

### 지도

<img src="https://p.ipic.vip/0co6bk.png" alt="IMG_0362"  width="200" height="432" /><img src="https://p.ipic.vip/ovfa5s.png" alt="IMG_0364"  width="200" height="432" /><img src="https://p.ipic.vip/sad2io.png" alt="IMG_0365"  width="200" height="432" /><img src="https://p.ipic.vip/q5dscv.png" alt="IMG_0366"  width="200" height="432" />


1. 메인 뷰입니다. 앱을 켜면 바로 등장합니다.
2. 산책을 시작하면 실시간으로 산책 시간과 영역 넓이를 계산하여 보여줍니다.
3. 영역 추가 버튼을 통해 영역을 추가할 수 있고, 추가된 영역을 클릭하여 삭제할 수 있습니다.
4. 산책이 완료되면 영역의 폴리곤을 오버레이한 사진을 코어데이터에 저장하고 관련 정보를 보여줍니다.
   1. 공유하기 기능은 아직 미구현입니다.
5. 저장하기 버튼을 통해 완성된 이미지를 사진첩에 저장할 수 있습니다.
6. 확인 버튼을 통해 뷰를 내릴 수 있습니다.

### 미정

### 설정

유저 정보와 설정값, 회원 탈퇴 등의 기능이 필요
