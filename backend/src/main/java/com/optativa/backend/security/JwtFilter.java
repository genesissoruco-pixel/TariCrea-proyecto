package com.optativa.backend.security;

import com.optativa.backend.repository.UsuarioRepository;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.dao.DataAccessException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.List;

public class JwtFilter extends OncePerRequestFilter {
    private final JwtService jwt;
    private final UsuarioRepository usuarios;
    public JwtFilter(JwtService jwt, UsuarioRepository usuarios) { this.jwt = jwt; this.usuarios = usuarios; }
    @Override protected boolean shouldNotFilter(HttpServletRequest request) {
        String ruta = request.getRequestURI().substring(request.getContextPath().length());
        return ruta.equals("/api/auth/login") || ruta.equals("/api/auth/registro")
                || ("GET".equals(request.getMethod()) && (ruta.startsWith("/api/public/") || ruta.startsWith("/api/imagenes/")));
    }
    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String cabecera = request.getHeader("Authorization");
        if (cabecera != null) {
            try {
                if (!cabecera.startsWith("Bearer ")) throw new JwtException("Bearer requerido");
                Long id = jwt.validar(cabecera.substring(7));
                var usuario = usuarios.findById(id).filter(u -> u.isActivo()).orElseThrow(() -> new JwtException("Cuenta inválida"));
                SecurityContextHolder.getContext().setAuthentication(
                        new UsernamePasswordAuthenticationToken(usuario.getId(), null, List.of()));
            } catch (JwtException | IllegalArgumentException ex) {
                SecurityContextHolder.clearContext();
                error(response, 401);
                return;
            } catch (DataAccessException ex) {
                SecurityContextHolder.clearContext();
                error(response, 503);
                return;
            }
        }
        chain.doFilter(request, response);
    }
    public static void error(HttpServletResponse response, int estado) throws IOException {
        response.setStatus(estado);
        response.setContentType("application/json;charset=UTF-8");
        String mensaje = switch (estado) {
            case 401 -> "Debe iniciar sesión.";
            case 403 -> "Acceso denegado.";
            default -> "No se pudo verificar la sesión. Reintente.";
        };
        response.getWriter().write("{\"success\":false,\"message\":\"" + mensaje + "\",\"data\":null}");
    }
}
