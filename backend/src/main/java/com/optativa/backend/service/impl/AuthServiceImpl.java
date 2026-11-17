package com.optativa.backend.service.impl;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.UsuarioResponse;
import com.optativa.backend.exception.ApiException;
import com.optativa.backend.model.Usuario;
import com.optativa.backend.repository.UsuarioRepository;
import com.optativa.backend.security.*;
import com.optativa.backend.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

@Service @RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {
    private final UsuarioRepository usuarios;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final UsuarioActual actual;

    @Override @Transactional
    public UsuarioResponse registrar(RegistroRequest request) {
        String correo = request.correo().strip().toLowerCase(Locale.ROOT);
        if (usuarios.existsByCorreo(correo)) throw ApiException.conflicto("El correo ya está registrado.");
        Usuario usuario = new Usuario();
        usuario.setNombre(request.nombre().strip());
        usuario.setApellidoPaterno(request.apellidoPaterno().strip());
        usuario.setApellidoMaterno(request.apellidoMaterno().strip());
        usuario.setTelefono(request.telefono().strip());
        usuario.setCorreo(correo);
        usuario.setContrasenaHash(encoder.encode(request.contrasena()));
        return UsuarioResponse.de(usuarios.saveAndFlush(usuario));
    }
    @Override @Transactional(readOnly = true)
    public Sesion login(LoginRequest request) {
        Usuario usuario = usuarios.findByCorreo(request.correo().strip().toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new BadCredentialsException("Credenciales inválidas"));
        if (!usuario.isActivo() || request.contrasena().getBytes(StandardCharsets.UTF_8).length > 72
                || !encoder.matches(request.contrasena(), usuario.getContrasenaHash()))
            throw new BadCredentialsException("Credenciales inválidas");
        return new Sesion(jwt.emitir(usuario.getId()), UsuarioResponse.de(usuario));
    }
    @Override @Transactional(readOnly = true)
    public UsuarioResponse me() {
        return UsuarioResponse.de(usuarios.findById(actual.id()).filter(Usuario::isActivo)
                .orElseThrow(() -> new BadCredentialsException("Cuenta inválida")));
    }
}
