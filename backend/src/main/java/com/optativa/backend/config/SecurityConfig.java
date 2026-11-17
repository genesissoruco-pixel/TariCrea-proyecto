package com.optativa.backend.config;

import com.optativa.backend.security.*;
import com.optativa.backend.repository.UsuarioRepository;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {
    @Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }
    @Bean SecurityFilterChain seguridad(HttpSecurity http, JwtService jwt, UsuarioRepository usuarios) throws Exception {
        return http.csrf(c -> c.disable()).sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .requestCache(c -> c.disable())
                .exceptionHandling(e -> e.authenticationEntryPoint((req, res, ex) -> JwtFilter.error(res, 401))
                        .accessDeniedHandler((req, res, ex) -> JwtFilter.error(res, 403)))
                .authorizeHttpRequests(a -> a
                        .requestMatchers(HttpMethod.POST, "/api/auth/registro", "/api/auth/login").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/public/**", "/api/imagenes/**").permitAll()
                        .anyRequest().authenticated())
                .addFilterBefore(new JwtFilter(jwt, usuarios), UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(new LimiteAutenticacionFilter(), JwtFilter.class)
                .build();
    }
}
