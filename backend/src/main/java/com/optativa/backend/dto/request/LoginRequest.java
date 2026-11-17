package com.optativa.backend.dto.request;

import jakarta.validation.constraints.*;

public record LoginRequest(
        @NotBlank @Email @Size(max = 254) String correo,
        @NotBlank @Size(max = 128) String contrasena) {}
