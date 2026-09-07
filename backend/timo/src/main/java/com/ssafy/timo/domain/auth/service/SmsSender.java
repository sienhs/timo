package com.ssafy.timo.domain.auth.service;

public interface SmsSender {

    // SmsSender는 local과 prod가 갈리는 부분이라 남겨 놓음.
    void sendVerificationCode(String phoneNumber, String code);
}
