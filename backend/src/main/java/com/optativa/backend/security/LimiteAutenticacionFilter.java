package com.optativa.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.LongSupplier;

public class LimiteAutenticacionFilter extends OncePerRequestFilter {
    private final Ventana login;
    private final Ventana registro;

    public LimiteAutenticacionFilter() {
        this(System::nanoTime);
    }

    LimiteAutenticacionFilter(LongSupplier reloj) {
        login = new Ventana(20, reloj);
        registro = new Ventana(10, reloj);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String ruta = request.getRequestURI().substring(request.getContextPath().length());
        Ventana ventana = switch (ruta) {
            case "/api/auth/login" -> login;
            case "/api/auth/registro" -> registro;
            default -> null;
        };
        if (ventana != null && "POST".equals(request.getMethod())) {
            long espera = ventana.intentar(request.getRemoteAddr());
            if (espera > 0) {
                response.setStatus(429);
                response.setHeader("Retry-After", Long.toString(espera));
                response.setContentType("application/json;charset=UTF-8");
                response.getWriter().write("{\"success\":false,\"message\":\"Demasiados intentos. Intente más tarde.\",\"data\":null}");
                return;
            }
        }
        chain.doFilter(request, response);
    }

    private static final class Ventana {
        private static final long DURACION = TimeUnit.MINUTES.toNanos(1);
        private static final int MAX_DIRECCIONES = 10_000;
        private final Map<String, Integer> intentos = new HashMap<>();
        private final int limite;
        private final LongSupplier reloj;
        private long inicio;

        private Ventana(int limite, LongSupplier reloj) {
            this.limite = limite;
            this.reloj = reloj;
            this.inicio = reloj.getAsLong();
        }

        private synchronized long intentar(String direccion) {
            long ahora = reloj.getAsLong();
            if (ahora - inicio >= DURACION) {
                intentos.clear();
                inicio = ahora;
            }
            int cantidad = intentos.getOrDefault(direccion, 0);
            if (cantidad >= limite || (cantidad == 0 && intentos.size() >= MAX_DIRECCIONES)) {
                long restante = DURACION - (ahora - inicio);
                return TimeUnit.NANOSECONDS.toSeconds(restante - 1) + 1;
            }
            intentos.put(direccion, cantidad + 1);
            return 0;
        }
    }
}
