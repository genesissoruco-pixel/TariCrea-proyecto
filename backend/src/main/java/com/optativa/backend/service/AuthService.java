package com.optativa.backend.service;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.UsuarioResponse;

public interface AuthService {
    UsuarioResponse registrar(RegistroRequest request);
    Sesion login(LoginRequest request);
    UsuarioResponse me();
    record Sesion(String token, UsuarioResponse usuario) {}
}
