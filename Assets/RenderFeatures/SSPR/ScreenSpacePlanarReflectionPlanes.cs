using System;
using UnityEngine;
using UnityEngine.Rendering;

public class ScreenSpacePlanarReflectionPlanes : MonoBehaviour
{
    public GameObject[] reflectionPlanes;
    private ScreenSpacePlanarReflectionVolume sspr;
    private void OnValidate() 
    {
        var stack = VolumeManager.instance.stack;
        sspr = stack.GetComponent<ScreenSpacePlanarReflectionVolume>();
        if (sspr == null || !sspr.IsActive() || sspr.maximumCount.value == 0) return;
        int index = 0;
        for (int i = 0; i < reflectionPlanes.Length; i++)
        {
            if (reflectionPlanes[i] == null) continue;
            sspr.reflectionPlanes[index] = reflectionPlanes[i];
            index++;
        }
    }
}