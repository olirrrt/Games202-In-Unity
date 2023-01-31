#include "denoiser.h"

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            auto posWorld = frameInfo.m_position(x, y);
            auto id = frameInfo.m_id(x, y);
            auto currWorldToCamera = Inverse(frameInfo.m_matrix[id]);
            auto type = Float3::EType::Point;
            auto preWorldToCamera = m_preFrameInfo.m_matrix[id];
            auto preScreenUV = preWorldToScreen(
                preWorldToCamera(currWorldToCamera(posWorld, type), type), type);

            m_valid(x, y) = false;
            if (preScreenUV.x <= width && preScreenUV.x >= 0. &&
                preScreenUV.y <= height && preScreenUV.y >= 0.) {
                // 上一帧在屏幕内
                if (id == m_preFrameInfo.m_id(preScreenUV.x, preScreenUV.y)) {
                    // 上一帧和当前帧为同一物体
                    m_valid(x, y) = true;
                    m_misc(x, y) = m_accColor(preScreenUV.x, preScreenUV.y);
                }
            }
        }
    }
    std::swap(m_misc, m_accColor); // m_accColor = m_misc;
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 color = m_accColor(x, y);
            Float3 avg = Float3(0.);
            Float3 sigma = Float3(0.);
            for (int i = 0; i < kernelRadius; i++) {
                for (int j = 0; j < kernelRadius; j++) {
                    avg += m_misc(x, y);
                }
            }
            avg /= kernelRadius * kernelRadius;
            for (int i = 0; i < kernelRadius; i++) {
                for (int j = 0; j < kernelRadius; j++) {
                    auto tmp = m_misc(x, y) - avg;
                    sigma += Float3(tmp.x * tmp.x, tmp.y * tmp.y, tmp.z * tmp.z);
                }
            }
            sigma /= kernelRadius * kernelRadius;
            color = Clamp(color, avg - sigma * m_colorBoxK, avg + sigma * m_colorBoxK);
            // TODO: Exponential moving average
            float alpha = (m_valid(x, y)) ? m_alpha : 1.0f;
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}
const int FILTER_SIZE = 3;
const int offsets[3] = {-1, 0, 1};
Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter
            auto col_i = frameInfo.m_beauty(x, y);
            auto depth_i = frameInfo.m_depth(x, y);
            auto normal_i = frameInfo.m_normal(x, y);
            auto posWorld_i = frameInfo.m_position(x, y);
            Float3 res = Float3(0.);
            float wSum = 0.;
            float kernel[3][3] = {0.};
            for (int i = 0; i < FILTER_SIZE; i++) {
                for (int j = 0; j < FILTER_SIZE; j++) {
                    auto x_j = x + offsets[i];
                    auto y_j = y + offsets[j];
                    auto col_j = frameInfo.m_beauty(x_j, y_j);
                    auto depth_j = frameInfo.m_depth(x_j, y_j);
                    auto normal_j = frameInfo.m_normal(x_j, y_j);
                    auto posWorld_j = frameInfo.m_position(x_j, y_j);
                    auto w =
                        exp(-pow(Distance(posWorld_i, posWorld_j), 2) /
                                (2 * m_sigmaCoord * m_sigmaCoord) -
                            pow(Distance(col_i, col_j), 2) /
                                (2 * m_sigmaColor * m_sigmaColor) -
                            pow(acos(Dot(normal_i, normal_j)), 2) /
                                (2 * m_sigmaNormal * m_sigmaNormal) -
                            pow(Dot(normal_i,
                                    (posWorld_j - posWorld_i) /
                                        Max(0.001, Distance(posWorld_i, posWorld_j))),2) /
                                (2 * m_sigmaPlane * m_sigmaPlane));
                    kernel[i][j] = w;
                    wSum += w;
                }
            }

            if (wSum < 1e-6) {                
                wSum = 1.;
            } else {            
                wSum = 1. / wSum;
            }
            for (int i = 0; i < FILTER_SIZE; i++) {
                for (int j = 0; j < FILTER_SIZE; j++) {
                    res += frameInfo.m_beauty(x + offsets[i], y + offsets[j]) *
                           kernel[i][j] * wSum; // 归一化
                }
            }
            filteredImage(x, y) = res;
        }
    }
    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;

    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
      //  Reprojection(frameInfo);
     //   TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
