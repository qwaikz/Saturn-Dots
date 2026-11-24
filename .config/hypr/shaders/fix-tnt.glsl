#version 300 es

precision mediump float;
in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    
    // Let more green through to stop it from being purple
    color.g = color.g * 0.75; 
    
    fragColor = color;
}
