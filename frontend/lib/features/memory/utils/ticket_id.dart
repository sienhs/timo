/// 티켓 번호 끝 여섯 자리. 뷰어 뒷면과 오르골 뒷면이 같은 번호를 찍어야
/// 해서 한 곳에서만 만든다.
///
/// 서버 티켓 번호는 `12` 처럼 짧아 그대로 쓴다 — 예전 목 번호(`ticket-1024`)만
/// 보고 끝을 잘라 내던 것이 짧은 번호에서 터졌다.
String shortTicketId(String id) =>
    id.length <= 6 ? id : id.substring(id.length - 6);
