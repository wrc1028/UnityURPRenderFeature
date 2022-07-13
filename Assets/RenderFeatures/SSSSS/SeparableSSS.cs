using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class SeparableSSS
{
    public static void CalculateKernel(ref List<Vector4> kernel, int sampleCounts, Vector3 strength, Vector3 falloff)
    {
        float range = sampleCounts > 20 ? 3.0f : 2.0f;
        float exponent = 2.0f;
        kernel.Clear();

        float step = 2.0f * range / (sampleCounts - 1);
        for (int i = 0; i < sampleCounts; i++)
        {
            float o = -range + i * step;
            float sign = o < 0.0f ? -1.0f : 1.0f;
            float w = sign * range * Mathf.Abs(Mathf.Pow(o, exponent)) / Mathf.Pow(range, exponent);
            kernel.Add(new Vector4(0, 0, 0, w));
        }

        for (int i = 0; i < sampleCounts; i++)
        {
            float w0 = i > 0 ? Mathf.Abs(kernel[i].w - kernel[i - 1].w) : 0.0f;
            float w1 = i < sampleCounts - 1 ? Mathf.Abs(kernel[i].w - kernel[i + 1].w) : 0.0f;
            float area = (w0 + w1) / 2.0f;
            Vector3 temp = DiffusionProfile(kernel[i].w, falloff) * area;
            kernel[i] = new Vector4(temp.x, temp.y, temp.z, kernel[i].w);
        }
        Vector4 t = kernel[sampleCounts / 2];
        for (int i = sampleCounts / 2; i > 0; i--)
            kernel[i] = kernel[i - 1];
        
        kernel[0] = t;
        Vector4 sum = Vector4.zero;

        for (int i = 0; i < sampleCounts; i++)
        {
            sum.x += kernel[i].x;
            sum.y += kernel[i].y;
            sum.z += kernel[i].z;
        }

        for (int i = 0; i < sampleCounts; i++)
        {
            Vector4 vector = kernel[i];
            vector.x /= sum.x;
            vector.y /= sum.y;
            vector.z /= sum.z;
            kernel[i] = vector;
        }
        Vector4 vec0 = kernel[0];
        for (int i = 0; i < sampleCounts; i++)
        {
            Vector4 vec = kernel[i];
            if (i == 0)
            {
                vec.x = (1.0f - vec.x) * strength.x;
                vec.y = (1.0f - vec.y) * strength.y;
                vec.z = (1.0f - vec.z) * strength.z;
            }
            vec.x = vec.x * strength.x;
            vec.y = vec.y * strength.y;
            vec.z = vec.z * strength.z;
            kernel[i] = vec;
        }
    }

    private static float Gaussian(float variance, float radius, float skinColorChannel)
    {
        float r1 = radius / (0.0001f + skinColorChannel);
        float r2 = r1 * r1;
        return Mathf.Exp(-r2 / (2.0f * variance)) / (2.0f * 3.14159f * variance);
    }

    private static Vector3 GaussianColor(float variance, float radius, Vector3 skinColor)
    {
        return new Vector3(Gaussian(variance, radius, skinColor.x), 
                           Gaussian(variance, radius, skinColor.y),
                           Gaussian(variance, radius, skinColor.z));
    }

    private static Vector3 DiffusionProfile(float radius, Vector3 skinColor)
    {
        return 0.100f * GaussianColor(0.0484f,radius, skinColor) + 
               0.118f * GaussianColor(0.187f, radius, skinColor) + 
               0.113f * GaussianColor(0.567f, radius, skinColor) + 
               0.358f * GaussianColor(1.990f, radius, skinColor) + 
               0.078f * GaussianColor(7.410f, radius, skinColor);
    }
}
