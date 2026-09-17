package com.ssafy.timo.domain.notification.dto;

import com.ssafy.timo.domain.notification.entity.PushPlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PushDeviceRegistrationRequest(
        @NotBlank @Size(max = 512) String token,
        @NotNull PushPlatform platform) {
}
