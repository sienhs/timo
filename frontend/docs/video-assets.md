# 영상 자산

## wallet_creating.mp4

가입 직후 지갑 준비 연출([WalletCreatingScreen])에 쓰는 클립. 너구리가 지갑에
버섯을 담는다.

원본은 배경이 `#D0D0D0`~`#E2E0E1` 의 스튜디오 회색이라, 흰 페이지 위에 놓으면
회색 사각형이 떠 보였다. **배경을 페이지와 같은 흰색으로 눌러서** 넣었다.
그래서 화면 쪽에서 테두리나 카드를 두르지 않는다 — 두르면 그 테두리가 대신
떠 보인다.

```bash
ffmpeg -i <원본>.mp4 \
  -vf "colorlevels=rimax=0.80:gimax=0.80:bimax=0.80" \
  -an -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart \
  wallet_creating.mp4
```

- `0.80` 은 배경을 완전히 날리면서 너구리 털의 밝은 부분은 남기는 값이다.
  올리면 배경에 회색이 남고, 내리면 털이 날아간다.
- `-an` 으로 소리를 버린다. 어차피 음소거로 재생하고, 파일도 가벼워진다.
- 영상을 갈아 끼울 때는 같은 처리를 거치고, 모든 프레임의 가장자리가 흰색인지
  확인한다. 배경이 균일하지 않은 영상이라면 이 방법이 통하지 않으니 화면 쪽
  배치부터 다시 정해야 한다.

## creating.mp4

소장품 제작 연출([CreatingClip])에 쓰는 클립. 털뭉치 생물이 색종이를 붙여
선물을 만들고, 마지막에 완성된 선물을 든다. 그래서 한 클립이 "제작중" 과
"완료" 를 함께 맡는다 — 제작 중에는 6.5초 지점에서 앞으로 되감아 만드는
장면만 되풀이하고, 제작이 끝나면 되감기를 풀어 마지막 장면까지 흘려보낸 뒤
그 프레임에서 멈춘다.

원본 배경은 `#F1F1F1` 의 스튜디오 흰색이라 제작 화면(흰 종이)에 놓으면 아주
옅은 회색 사각형이 떠 보였다. 같은 방식으로 **배경을 흰색까지 눌러서** 넣는다.

```bash
ffmpeg -i <원본>.mp4 \
  -vf "colorlevels=rimax=0.93:gimax=0.93:bimax=0.93" \
  -an -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart \
  creating.mp4
```

- 이 원본은 네 귀퉁이가 살짝 어둡고 따뜻해서(비네팅) 레벨만으로는 250 언저리에
  머문다. 더 누르면 털의 밝은 부분이 날아가므로, 남은 자국은 화면 쪽에서
  지운다 — [CreatingClip] 이 바깥을 투명하게 지우는 원형 마스크를 씌운다.
- 클립을 갈아 끼울 때는 만드는 장면과 완성 장면이 한 클립 안에 있어야 하고,
  그 경계를 `CreatorLayout.clipMakingEnd` 로 다시 잡는다.

## transferring.mp4

양도 결제 대기 연출([PurchaseTransferringView])에 쓰는 클립. 너구리가 편지를
전한다. 서버가 온체인 체결까지 끝내고 답하는 동안(최대 30초) 재생되므로,
클립 길이(8초)보다 기다림이 길 수 있어 **반복 재생**한다. 첫 프레임과 끝
프레임의 자세가 거의 같아 이음매가 드러나지 않는다.

원본 배경은 `#E8E8E8` 의 스튜디오 회색이고 모든 프레임에서 균일하다.
`wallet_creating.mp4` 와 같은 방식으로 **배경을 흰색까지 눌러서** 넣는다.

```bash
ffmpeg -i <원본>.mp4 \
  -vf "colorlevels=rimax=0.89:gimax=0.89:bimax=0.89" \
  -an -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart \
  transferring.mp4
```

- `0.89` 는 배경이 `#FFFFFF` 에 닿는 값이다. 배경값 232 를 그대로 환산한
  `0.91` 로는 253~254 가 남아 흰 화면 위에서 사각형이 비쳤다. 더 내리면 흰
  봉투와 너구리 털의 밝은 부분이 서로 먹는다.
- 화면(마켓)의 배경은 `#F4F5F6` 라 이 클립을 그대로 올리면 흰 사각형이 떠
  보인다. 그래서 연출이 도는 동안에는 **화면을 흰 바탕으로 바꾼다**
  ([ListingPurchaseScreen] 의 `_purchasing` 갈래).

## issuing.mp4

티켓 발행 대기 연출([TicketIssuingView])에 쓰는 클립. 너구리가 티켓을 써서
(0~3.4초) 다 쓴 티켓을 들어 내민다(3.4~8초).

**앞 구간만 되풀이한다.** 서버가 잔액 차감과 발행 두 트랜잭션을 확정하기를
기다리는 동안 재생되는데(최대 2분), 클립을 통째로 돌리면 아직 발행 중인데도
완성된 티켓이 주기적으로 나타나 다 됐다고 말하는 꼴이 된다. 되감는 지점은
`PaymentConstants.issuingClipLoopEnd` 다 — 클립을 갈아 끼우면 이 값도 다시
잡는다. 카메라가 클립 내내 천천히 다가와서 되감길 때 크기가 한 번 튀는데,
`creating.mp4` 와 같은 정도라 그대로 둔다.

원본 배경은 `#E7E7E7`~`#E9E9E9` 의 스튜디오 회색이고 모든 프레임에서 균일하다.
`transferring.mp4` 와 같은 방식으로 **배경을 흰색까지 눌러서** 넣는다.

```bash
ffmpeg -i <원본>.mp4 \
  -vf "colorlevels=rimax=0.89:gimax=0.89:bimax=0.89" \
  -an -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart \
  issuing.mp4
```

- `0.89` 로 네 가장자리가 전부 흰색(제한 범위 Y=235)에 닿는다. 확인은
  `ffmpeg -i issuing.mp4 -vf "crop=1280:6:0:0,signalstats,metadata=print:key=lavfi.signalstats.YMIN:file=-" -f null -`
  로 가장자리 띠의 최솟값을 프레임마다 찍어 본다. 아래쪽 띠는 너구리 발과
  그림자가 닿아 있어 어두운 값이 나오는 것이 정상이다.
- 화면(완료 화면)의 배경은 `#F4F5F6` 라 이 클립을 그대로 올리면 흰 사각형이
  떠 보인다. 그래서 연출이 도는 동안에는 **화면을 흰 바탕으로 바꾼다**
  ([PaymentCompleteScreen] 의 `_waiting` 갈래).
