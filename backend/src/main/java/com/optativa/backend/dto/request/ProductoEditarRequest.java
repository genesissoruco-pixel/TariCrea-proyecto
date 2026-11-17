package com.optativa.backend.dto.request;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public record ProductoEditarRequest(
        @NotBlank @Size(max = 150) String nombre,
        @NotBlank String descripcion,
        @NotNull @DecimalMin("0") @Digits(integer = 8, fraction = 2) BigDecimal precio,
        @NotNull Boolean publicado) {}
