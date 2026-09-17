package com.ssafy.timo.domain.notification.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PushDeviceUnregistrationRequest(@NotBlank @Size(max = 512) String token) {
}
