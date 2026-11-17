package com.optativa.backend.dto.response;

import com.optativa.backend.model.Usuario;

public record UsuarioResponse(Long id, String nombre, String correo,
        String apellidoPaterno, String apellidoMaterno, String telefono) {
    public static UsuarioResponse de(Usuario usuario) {
        return new UsuarioResponse(usuario.getId(), usuario.getNombre(), usuario.getCorreo(),
                usuario.getApellidoPaterno(), usuario.getApellidoMaterno(), usuario.getTelefono());
    }
}
