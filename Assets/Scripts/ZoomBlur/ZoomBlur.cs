using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[VolumeComponentMenu("Custom/ZoomBlur")]
public class ZoomBlur : VolumeComponent, IPostProcessComponent
{
    [Range(0.0f, 100.0f), Tooltip("加强效果使模糊效果更强")]
    public FloatParameter focusPower = new FloatParameter(0.0f);
    [Range(0, 10), Tooltip("值越大越好, 但是负载将增加")]
    public IntParameter focusDetail = new IntParameter(0);
    [Tooltip("模糊中心坐标")]
    public Vector2Parameter focusScreenPositon = new Vector2Parameter(Vector2.zero);
    [Tooltip("参考宽度分辨率")]
    public IntParameter referenceResolutionX = new IntParameter(1334);

    public bool IsActive() => active && focusPower.value > 0.0f;
    public bool IsTileCompatible() => false;
}
