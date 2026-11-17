package com.optativa.backend.config;

import com.optativa.backend.dto.response.ApiResponse;
import com.optativa.backend.exception.ApiException;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.*;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import java.util.*;

@RestControllerAdvice @Slf4j
public class GlobalExceptionHandler {
    @ExceptionHandler(ApiException.class)
    ResponseEntity<?> api(ApiException ex) { return respuesta(ex.getStatus(), ex.getMessage()); }
    @ExceptionHandler(AuthenticationException.class)
    ResponseEntity<?> autenticacion() { return respuesta(HttpStatus.UNAUTHORIZED, "Credenciales o sesión inválidas."); }
    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<?> permiso() { return respuesta(HttpStatus.FORBIDDEN, "No tiene permiso para modificar este recurso."); }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<?> campos(MethodArgumentNotValidException ex) {
        Map<String, String> errores = new TreeMap<>();
        ex.getBindingResult().getFieldErrors().forEach(e -> errores.putIfAbsent(e.getField(), e.getDefaultMessage()));
        return ResponseEntity.badRequest().body(ApiResponse.error("Revise los campos indicados.", errores));
    }
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    ResponseEntity<?> tamano() { return respuesta(HttpStatus.PAYLOAD_TOO_LARGE, "La fotografía supera el tamaño permitido."); }
    @ExceptionHandler({HttpMessageNotReadableException.class, MultipartException.class,
            MissingServletRequestParameterException.class, MethodArgumentTypeMismatchException.class,
            ConstraintViolationException.class, IllegalArgumentException.class,
            org.springframework.web.multipart.support.MissingServletRequestPartException.class})
    ResponseEntity<?> formato() { return respuesta(HttpStatus.BAD_REQUEST, "Solicitud inválida. Revise datos y partes multipart."); }
    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<?> integridad() { return respuesta(HttpStatus.CONFLICT, "Los datos entran en conflicto con un registro o restricción existente."); }
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<?> datos() { return respuesta(HttpStatus.SERVICE_UNAVAILABLE, "No se pudo acceder a los datos. Reintente."); }
    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<?> inexistente() { return respuesta(HttpStatus.NOT_FOUND, "Recurso no encontrado."); }
    @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class)
    ResponseEntity<?> metodo() { return respuesta(HttpStatus.METHOD_NOT_ALLOWED, "Método no admitido."); }
    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    ResponseEntity<?> contenido() { return respuesta(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "Tipo de contenido no admitido."); }
    @ExceptionHandler(Exception.class)
    ResponseEntity<?> inesperado(Exception ex) {
        log.error("Error no controlado", ex);
        return respuesta(HttpStatus.INTERNAL_SERVER_ERROR, "No se pudo completar la operación.");
    }
    private ResponseEntity<?> respuesta(HttpStatus estado, String mensaje) {
        return ResponseEntity.status(estado).body(ApiResponse.error(mensaje, null));
    }
}
