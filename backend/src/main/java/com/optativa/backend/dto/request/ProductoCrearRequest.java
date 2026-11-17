package com.optativa.backend.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.UUID;

public record ProductoCrearRequest(
        @JsonProperty("cliente_uuid") @NotNull UUID clienteUuid,
        @NotBlank @Size(max = 150) String nombre,
        @NotBlank String descripcion,
        @NotNull @DecimalMin("0") @Digits(integer = 8, fraction = 2) BigDecimal precio,
        @NotNull Boolean publicado) {}
