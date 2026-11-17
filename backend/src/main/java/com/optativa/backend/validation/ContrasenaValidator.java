package com.optativa.backend.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import java.nio.charset.StandardCharsets;

public class ContrasenaValidator implements ConstraintValidator<ContrasenaValida, String> {
    @Override public boolean isValid(String valor, ConstraintValidatorContext contexto) {
        return valor != null && !valor.isBlank() && valor.codePointCount(0, valor.length()) >= 8
                && valor.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
}
