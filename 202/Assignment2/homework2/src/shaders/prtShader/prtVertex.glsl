attribute vec3 aVertexPosition;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

attribute mat3 aPrecomputeLT;
uniform mat3 uPrecomputeLR;
uniform mat3 uPrecomputeLG;
uniform mat3 uPrecomputeLB;

varying vec3 vColor;

void main(void) {
    vColor = vec3(0.1);
    for(int i = 0; i < 3; i++){
        for(int j = 0; j < 3; j++){
            vColor += aPrecomputeLT[i][j] * vec3(uPrecomputeLR[i][j], uPrecomputeLG[i][j], uPrecomputeLB[i][j]);
        }
    }
    gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);
}
