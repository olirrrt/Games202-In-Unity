// https://mathjs.org/docs/reference/functions.html#matrix-functions
function getRotationPrecomputeL(precompute_L, rotationMatrix) {

	let mat3 = computeSquareMatrix_3by3(rotationMatrix);
	let mat5 = computeSquareMatrix_5by5(rotationMatrix);

	let result = [];

	for (let i = 0; i < 3; i++) {
		let res = math.multiply(mat3, [precompute_L[i][1], precompute_L[i][2], precompute_L[i][3]])._data;
		let res5 = math.multiply(mat5, [precompute_L[i][4], precompute_L[i][5], precompute_L[i][6], precompute_L[i][6], precompute_L[i][8]])._data;
		result.push([precompute_L[i][0], res[0], res[1], res[2], res5[0], res5[1], res5[2], res5[3], res5[4]]);
	}

	return result;
}

function computeSquareMatrix_3by3(rotationMatrix) { // 计算方阵SA(-1) 3*3 
	// 1、pick ni - {ni}
	// 对于第 l 层 band，选取 2l + 1 个 normal vector n
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [0, 1, 0, 0];
	let normals = [n1, n2, n3];
	let A = math.zeros(3, 3);
	let S = math.zeros(3, 3);
	let A_inverse = math.zeros(3, 3);
	//	let rotationMatrix_trans = math.transpose(mat4Matrix2mathMatrix(rotationMatrix)); // 数列转换为math.mat
	let rotationMatrix_trans = (mat4Matrix2mathMatrix(rotationMatrix)); // 数列转换为math.mat

	// 2、{P(ni)} - A  A_inverse
	// 计算(2l + 1)个n各自在球谐上的投影，每个有(2l + 1)个系数，构成(2l + 1) * (2l + 1)的矩阵A，并求其逆矩阵
	for (let i = 0; i < 3; i++) {
		let proj = SHEval3(normals[i][0], normals[i][1], normals[i][2]);

		for (let j = 1; j < 4; j++)
			A.set([j - 1, i], proj[j]);// i行j列

	}

	A_inverse = math.inv(A);

	// 3、用 R 旋转 ni - {R(ni)}
	// 4、R(ni) SH投影 - S
	// 用输入的旋转矩阵旋转ni，并将结果投影，类似步骤2，得到(2l + 1) * (2l + 1)的矩阵S
	for (let i = 0; i < 3; i++) {
		//let vec = math.matrix([normals[i][0], normals[i][1], normals[i][2], 0]); // col vector  
		//let n = math.multiply(rotationMatrix_trans, vec)._data;// (4 * 4) * (4 * 1) 第一个列数等于第二个行数
		let n = vec4.create();
		vec4.transformMat4(n, normals[i], rotationMatrix);

		let proj = SHEval3(n[0], n[1], n[2]);

		for (let j = 1; j < 4; j++)
			S.set([j - 1, i], proj[j]);

	}

	// 5、S*A_inverse
	return math.multiply(S, A_inverse);
}

function computeSquareMatrix_5by5(rotationMatrix) { // 计算方阵SA(-1) 5*5

	// 1、pick ni - {ni}
	let k = 1 / math.sqrt(2);
	let n1 = [1, 0, 0, 0]; let n2 = [0, 0, 1, 0]; let n3 = [k, k, 0, 0];
	let n4 = [k, 0, k, 0]; let n5 = [0, k, k, 0];
	let normals = [n1, n2, n3, n4, n5];
	let A = math.zeros(5, 5);
	let S = math.zeros(5, 5);
	let A_inverse = math.zeros(5, 5);
	let rotationMatrix_trans = math.transpose(mat4Matrix2mathMatrix(rotationMatrix)); // 数列转换为math.mat
	rotationMatrix_trans = mat4Matrix2mathMatrix(rotationMatrix);
	// 2、{P(ni)} - A  A_inverse
	// 计算(2l + 1)个n各自在球谐上的投影，每个有(2l + 1)个系数，构成(2l + 1) * (2l + 1)的矩阵A，并求其逆矩阵
	for (let i = 0; i < 5; i++) {
		let proj = SHEval3(normals[i][0], normals[i][1], normals[i][2]);

		for (let j = 4; j < 9; j++)
			A.set([j - 4, i], proj[j]);// i行j列
	}

	A_inverse = math.inv(A);

	// 3、用 R 旋转 ni - {R(ni)}
	// 4、R(ni) SH投影 - S
	// 用输入的旋转矩阵旋转ni，并将结果投影，类似步骤2，得到(2l + 1) * (2l + 1)的矩阵S
	for (let i = 0; i < 5; i++) {
		//let vec = math.matrix([normals[i][0], normals[i][1], normals[i][2], 0]); // col vector  
		//let n = math.multiply(vec, rotationMatrix_trans)._data;// (4 * 4) * (4 * 1) 第一个列数等于第二个行数
		let n = vec4.create();
		vec4.transformMat4(n, normals[i], rotationMatrix);

		let proj = SHEval3(n[0], n[1], n[2]);

		for (let j = 4; j < 9; j++)
			S.set([j - 4, i], proj[j]);

	}

	// 5、S*A_inverse
	return math.multiply(S, A_inverse);
}

function mat4Matrix2mathMatrix(rotationMatrix) {

	let mathMatrix = [];
	for (let i = 0; i < 4; i++) {
		let r = [];
		for (let j = 0; j < 4; j++) {
			r.push(rotationMatrix[i * 4 + j]);
		}
		mathMatrix.push(r);
	}
	return math.matrix(mathMatrix);

}

function getMat3ValueFromRGB(precomputeL) {

	let colorMat3 = [];
	for (var i = 0; i < 3; i++) {
		colorMat3[i] = mat3.fromValues(precomputeL[0][i], precomputeL[1][i], precomputeL[2][i],
			precomputeL[3][i], precomputeL[4][i], precomputeL[5][i],
			precomputeL[6][i], precomputeL[7][i], precomputeL[8][i]);
	}
	return colorMat3;
}