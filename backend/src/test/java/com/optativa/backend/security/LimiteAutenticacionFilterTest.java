package com.optativa.backend.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.assertEquals;

class LimiteAutenticacionFilterTest {
    @Test void permiteVolverAIntentarCuandoVenceLaVentana() throws Exception {
        AtomicLong reloj = new AtomicLong();
        var filtro = new LimiteAutenticacionFilter(reloj::get);
        for (int i = 0; i < 10; i++) {
            assertEquals(200, registrar(filtro).getStatus());
        }
        reloj.set(TimeUnit.SECONDS.toNanos(59));
        var bloqueada = registrar(filtro);
        assertEquals(429, bloqueada.getStatus());
        assertEquals("1", bloqueada.getHeader("Retry-After"));
        reloj.set(TimeUnit.MINUTES.toNanos(1));
        assertEquals(200, registrar(filtro).getStatus());
    }

    private MockHttpServletResponse registrar(LimiteAutenticacionFilter filtro) throws Exception {
        var request = new MockHttpServletRequest("POST", "/api/auth/registro");
        var response = new MockHttpServletResponse();
        filtro.doFilter(request, response, new MockFilterChain());
        return response;
    }
}
