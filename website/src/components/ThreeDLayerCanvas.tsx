import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';

interface ThreeDProps {
  selectedLayerId?: string;
  onSelectLayer?: (layerId: string) => void;
}

export const ThreeDLayerCanvas: React.FC<ThreeDProps> = ({ selectedLayerId = 'direct', onSelectLayer }) => {
  const mountRef = useRef<HTMLDivElement>(null);
  const [activeNode, setActiveNode] = useState<string | null>(null);
  const [isWireframe, setIsWireframe] = useState<boolean>(false);
  const [animSpeed, setAnimSpeed] = useState<number>(1);

  // References to meshes for camera focusing and wireframe toggling
  const mesh1Ref = useRef<THREE.Mesh | null>(null);
  const mesh2Ref = useRef<THREE.Mesh | null>(null);
  const mesh3Ref = useRef<THREE.Mesh | null>(null);
  const wireMat1Ref = useRef<THREE.MeshBasicMaterial | null>(null);
  const wireMat2Ref = useRef<THREE.MeshBasicMaterial | null>(null);
  const wireMat3Ref = useRef<THREE.MeshBasicMaterial | null>(null);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    const width = container.clientWidth;
    const height = container.clientHeight || 380;

    // Scene
    const scene = new THREE.Scene();
    
    // Camera
    const aspect = width / height;
    const camera = new THREE.PerspectiveCamera(40, aspect, 0.1, 1000);
    camera.position.set(0, 0, aspect < 1.8 ? 6.8 : 5.2);

    // Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    // Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 1.2);
    scene.add(ambientLight);

    const dirLight1 = new THREE.DirectionalLight(0xffffff, 2.5);
    dirLight1.position.set(5, 8, 5);
    scene.add(dirLight1);

    const dirLight2 = new THREE.DirectionalLight(0x6366f1, 2);
    dirLight2.position.set(-5, -5, 2);
    scene.add(dirLight2);

    const pointLight = new THREE.PointLight(0x10b981, 2.5, 25);
    pointLight.position.set(0, 2, 4);
    scene.add(pointLight);

    // Node 1: Layer 1 Direct
    const g1 = new THREE.IcosahedronGeometry(0.72, 0);
    const m1 = new THREE.MeshPhysicalMaterial({
      color: 0x6366f1,
      roughness: 0.15,
      metalness: 0.65,
      clearcoat: 1.0,
    });
    const mesh1 = new THREE.Mesh(g1, m1);
    mesh1.position.set(-1.7, 0, 0);
    mesh1.userData = { id: 'direct', name: '01 ⁄ Direct (Capabilities & Flow)' };
    scene.add(mesh1);
    mesh1Ref.current = mesh1;

    const wireMat1 = new THREE.MeshBasicMaterial({ color: 0xa5b4fc, wireframe: true, transparent: true, opacity: 0.4 });
    const wireMesh1 = new THREE.Mesh(new THREE.IcosahedronGeometry(0.75, 0), wireMat1);
    mesh1.add(wireMesh1);
    wireMat1Ref.current = wireMat1;

    // Node 2: Layer 2 Ship
    const g2 = new THREE.OctahedronGeometry(0.78, 0);
    const m2 = new THREE.MeshPhysicalMaterial({
      color: 0x10b981,
      roughness: 0.1,
      metalness: 0.75,
      clearcoat: 1.0,
    });
    const mesh2 = new THREE.Mesh(g2, m2);
    mesh2.position.set(0, 0, 0);
    mesh2.userData = { id: 'ship', name: '02 ⁄ Ship (PR Review & Evals)' };
    scene.add(mesh2);
    mesh2Ref.current = mesh2;

    const wireMat2 = new THREE.MeshBasicMaterial({ color: 0x6ee7b7, wireframe: true, transparent: true, opacity: 0.4 });
    const wireMesh2 = new THREE.Mesh(new THREE.OctahedronGeometry(0.81, 0), wireMat2);
    mesh2.add(wireMesh2);
    wireMat2Ref.current = wireMat2;

    // Node 3: Layer 3 Run
    const g3 = new THREE.TorusKnotGeometry(0.52, 0.18, 64, 16);
    const m3 = new THREE.MeshPhysicalMaterial({
      color: 0xa855f7,
      roughness: 0.2,
      metalness: 0.6,
      clearcoat: 0.8,
    });
    const mesh3 = new THREE.Mesh(g3, m3);
    mesh3.position.set(1.7, 0, 0);
    mesh3.userData = { id: 'run', name: '03 ⁄ Run (Personal Dev Tutor)' };
    scene.add(mesh3);
    mesh3Ref.current = mesh3;

    const wireMat3 = new THREE.MeshBasicMaterial({ color: 0xd8b4fe, wireframe: true, transparent: true, opacity: 0.4 });
    const wireMesh3 = new THREE.Mesh(new THREE.TorusKnotGeometry(0.55, 0.2, 64, 16), wireMat3);
    mesh3.add(wireMesh3);
    wireMat3Ref.current = wireMat3;

    // Orbit Ring
    const ringG = new THREE.TorusGeometry(1.9, 0.015, 16, 100);
    const ringM = new THREE.MeshBasicMaterial({ color: 0x64748b, wireframe: true, transparent: true, opacity: 0.3 });
    const ringMesh = new THREE.Mesh(ringG, ringM);
    ringMesh.rotation.x = Math.PI / 2.3;
    scene.add(ringMesh);

    // Star Field Particles
    const pCount = 300;
    const pPositions = new Float32Array(pCount * 3);
    for (let i = 0; i < pCount * 3; i++) {
      pPositions[i] = (Math.random() - 0.5) * 16;
    }
    const pGeom = new THREE.BufferGeometry();
    pGeom.setAttribute('position', new THREE.BufferAttribute(pPositions, 3));
    const pMat = new THREE.PointsMaterial({ size: 0.035, color: 0x94a3b8, transparent: true, opacity: 0.5 });
    const particles = new THREE.Points(pGeom, pMat);
    scene.add(particles);

    // Raycaster
    const raycaster = new THREE.Raycaster();
    const mouse = new THREE.Vector2(-100, -100);
    let mouseX = 0;
    let mouseY = 0;

    const handleMouseMove = (e: MouseEvent) => {
      const rect = renderer.domElement.getBoundingClientRect();
      mouse.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      mouse.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;

      mouseX = (e.clientX - (rect.left + rect.width / 2)) * 0.0006;
      mouseY = (e.clientY - (rect.top + rect.height / 2)) * 0.0006;
    };

    const handleClick = () => {
      raycaster.setFromCamera(mouse, camera);
      const intersects = raycaster.intersectObjects([mesh1, mesh2, mesh3]);
      if (intersects.length > 0) {
        const id = intersects[0].object.userData.id;
        if (onSelectLayer) onSelectLayer(id);
      }
    };

    const domEl = renderer.domElement;
    domEl.addEventListener('mousemove', handleMouseMove);
    domEl.addEventListener('click', handleClick);

    // Animation Loop
    let animId: number;
    const clock = new THREE.Clock();

    const renderLoop = () => {
      animId = requestAnimationFrame(renderLoop);
      const t = clock.getElapsedTime() * animSpeed;

      // Rotations
      mesh1.rotation.x = t * 0.4;
      mesh1.rotation.y = t * 0.6;
      mesh1.position.y = Math.sin(t * 1.5) * 0.07;

      mesh2.rotation.x = t * 0.5;
      mesh2.rotation.y = t * 0.4;
      mesh2.position.y = Math.sin(t * 1.5 + 1) * 0.07;

      mesh3.rotation.x = t * 0.6;
      mesh3.rotation.y = t * 0.5;
      mesh3.position.y = Math.sin(t * 1.5 + 2) * 0.07;

      ringMesh.rotation.z = t * 0.08;
      particles.rotation.y = t * 0.03;

      // Target X position for Camera focus based on selectedLayerId
      let targetCamX = 0;
      if (selectedLayerId === 'direct') targetCamX = -0.5;
      if (selectedLayerId === 'ship') targetCamX = 0;
      if (selectedLayerId === 'run') targetCamX = 0.5;

      // Parallax smooth camera movement
      camera.position.x += (targetCamX + mouseX * 2 - camera.position.x) * 0.06;
      camera.position.y += (-mouseY * 2 - camera.position.y) * 0.06;
      camera.lookAt(targetCamX * 0.5, 0, 0);

      // Raycast hover check
      raycaster.setFromCamera(mouse, camera);
      const intersects = raycaster.intersectObjects([mesh1, mesh2, mesh3]);

      if (intersects.length > 0) {
        const hit = intersects[0].object;
        domEl.style.cursor = 'pointer';
        setActiveNode(hit.userData.name);
        hit.scale.lerp(new THREE.Vector3(1.15, 1.15, 1.15), 0.1);
      } else {
        domEl.style.cursor = 'default';
        setActiveNode(null);
        mesh1.scale.lerp(new THREE.Vector3(1, 1, 1), 0.1);
        mesh2.scale.lerp(new THREE.Vector3(1, 1, 1), 0.1);
        mesh3.scale.lerp(new THREE.Vector3(1, 1, 1), 0.1);
      }

      renderer.render(scene, camera);
    };

    renderLoop();

    // Resize Observer
    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const newW = entry.contentRect.width;
        const newH = entry.contentRect.height || 380;
        if (newW > 0 && newH > 0) {
          const newAspect = newW / newH;
          camera.aspect = newAspect;
          camera.position.z = newAspect < 1.8 ? 6.8 : 5.2;
          camera.updateProjectionMatrix();
          renderer.setSize(newW, newH);
        }
      }
    });

    resizeObserver.observe(container);

    return () => {
      resizeObserver.disconnect();
      domEl.removeEventListener('mousemove', handleMouseMove);
      domEl.removeEventListener('click', handleClick);
      cancelAnimationFrame(animId);
      if (container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
    };
  }, [selectedLayerId, onSelectLayer, animSpeed]);

  // Wireframe toggle effect
  useEffect(() => {
    if (wireMat1Ref.current) wireMat1Ref.current.opacity = isWireframe ? 0.9 : 0.4;
    if (wireMat2Ref.current) wireMat2Ref.current.opacity = isWireframe ? 0.9 : 0.4;
    if (wireMat3Ref.current) wireMat3Ref.current.opacity = isWireframe ? 0.9 : 0.4;
  }, [isWireframe]);

  return (
    <div style={{
      position: 'relative',
      width: '100%',
      height: '380px',
      borderRadius: '6px',
      overflow: 'hidden',
      background: 'var(--bg-surface)',
      border: '1px solid var(--border-color)',
      marginBottom: '2.5rem'
    }}>
      <div ref={mountRef} style={{ width: '100%', height: '100%' }} />

      {/* Hallmark 3D Interactive Controls Overlay */}
      <div style={{
        position: 'absolute',
        top: '1rem',
        right: '1rem',
        display: 'flex',
        gap: '0.5rem',
        zIndex: 10
      }}>
        <button
          onClick={() => setIsWireframe(!isWireframe)}
          className={isWireframe ? 'hm-btn-primary' : 'hm-btn-secondary'}
          style={{ fontSize: '0.75rem', padding: '0.3rem 0.7rem' }}
        >
          <span>Wireframe {isWireframe ? 'ON' : 'OFF'}</span>
        </button>

        <button
          onClick={() => setAnimSpeed(animSpeed === 1 ? 2.5 : animSpeed === 2.5 ? 0.2 : 1)}
          className="hm-btn-secondary"
          style={{ fontSize: '0.75rem', padding: '0.3rem 0.7rem' }}
        >
          <span>Velocity: {animSpeed === 1 ? '1x' : animSpeed === 2.5 ? '2.5x' : '0.2x'}</span>
        </button>
      </div>

      {/* Hallmark Editorial 3D Controls Footer */}
      <div style={{
        position: 'absolute',
        bottom: '1rem',
        left: '1.2rem',
        right: '1.2rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        pointerEvents: 'none',
        fontFamily: 'var(--font-mono)',
        fontSize: '0.8rem'
      }}>
        <div style={{
          background: 'var(--bg-page)',
          padding: '0.4rem 0.8rem',
          borderRadius: '4px',
          border: '1px solid var(--border-color)',
          color: 'var(--text-muted)'
        }}>
          <span>3D Architecture Matrix (Three.js WebGL)</span>
        </div>

        {activeNode ? (
          <div style={{
            background: 'var(--accent)',
            color: '#ffffff',
            padding: '0.4rem 0.8rem',
            borderRadius: '4px',
            fontWeight: 700
          }}>
            <span>Click to inspect → {activeNode}</span>
          </div>
        ) : (
          <div style={{
            background: 'var(--bg-page)',
            padding: '0.4rem 0.8rem',
            borderRadius: '4px',
            border: '1px solid var(--border-color)',
            color: 'var(--text-secondary)'
          }}>
            <span>Pasa el ratón o haz clic en cualquier nodo 3D</span>
          </div>
        )}
      </div>
    </div>
  );
};
