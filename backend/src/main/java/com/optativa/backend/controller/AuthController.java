package com.optativa.backend.controller;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.*;
import com.optativa.backend.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/auth") @RequiredArgsConstructor
public class AuthController {
    private final AuthService auth;
    @PostMapping("/registro")
    public ResponseEntity<?> registrar(@Valid @RequestBody RegistroRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok("Cuenta registrada.", auth.registrar(request)));
    }
    @PostMapping("/login")
    public ApiResponse<?> login(@Valid @RequestBody LoginRequest request) { return ApiResponse.ok("Sesión iniciada.", auth.login(request)); }
    @GetMapping("/me")
    public ApiResponse<?> me() { return ApiResponse.ok("Usuario actual.", auth.me()); }
}
