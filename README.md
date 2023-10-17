# dogArea : 우리 댕댕이 영역 표시하기

<div align="left">
	<img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white"/>
  <img src="https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white"/>
</div>

## Idea : 강아지들이 산책 할 때 영역 표시를 하는데, 이걸 실제 지도 위에 표현해보자!



### 사용하는 기능

1. Map > location의 배열을 가지고 영역 폴리곤을 만들어야 함!
   1. 관련 function 구현되어 있는 KakaoMap 사용 > Mapkit으로 먼저 구현해보고 kakaomap으로 마이그레이션 하기로 했음 ( 시뮬레이션 문제 )
   2. Location tracking을 해서 그리기? 아님 특정 location에서 버튼 입력 받아서 영역 그리기?
2. Data storage
   1. SwiftData로 써보기
3. Location 권한 허용해서 가져오기, 날짜 별로 영역 DTO 만들어서 저장하기
   1. 외부 DB를 사용할지? 한다면 firebase? AWS?
4. User에 대한 고민 : 프로필 이미지를 캐릭터화 하고 싶다..
   1.OpenAI로 image generate하기
   
### 고도화에 대한 고민

1. 디자인의 영역
2. Watch app 개발 및 연동
3. 서버 개설 해서 Authorize 관리(로그인 회원가입 구현할까?)
