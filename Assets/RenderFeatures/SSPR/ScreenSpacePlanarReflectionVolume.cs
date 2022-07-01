using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom/ScreenSpacePlanarReflection")]
public class ScreenSpacePlanarReflectionVolume : VolumeComponent, IPostProcessComponent
{
    public FloatParameter waterHeight = new FloatParameter(0.0f);
    [Tooltip("最大支持反射平面数量")]
    public ClampedIntParameter maximumCount = new ClampedIntParameter(1, 0, 4);
    public GameObject[] reflectionPlanes = new GameObject[4];
    public bool IsActive() => active;
    public bool IsTileCompatible() => false;
}
