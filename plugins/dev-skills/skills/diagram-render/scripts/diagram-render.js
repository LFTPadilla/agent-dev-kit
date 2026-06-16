const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DEFAULT_OUTPUT_DIR = require("os").tmpdir();

function buildNetworkDiagram(nodes, connections, options) {
  const fontSize = options.fontSize || 12;
  const nodeW = options.nodeW || 140;
  const nodeH = options.nodeH || 60;
  const gapX = options.gapX || 60;
  const gapY = options.gapY || 50;
  const pad = 20;
  
  // Calculate grid dimensions
  const cols = Math.max(...nodes.map(n => n.col || 0)) + 1;
  const rows = Math.max(...nodes.map(n => n.row || 0)) + 1;
  
  const diagramW = cols * nodeW + (cols - 1) * gapX + pad * 2;
  const diagramH = rows * nodeH + (rows - 1) * gapY + pad * 2 + 40; // +40 for title
  
  const colorScheme = {
    cloud: '#3498DB',
    cluster: '#9B59B6',
    server: '#27AE60',
    vm: '#E67E22',
    pbs: '#1ABC9C',
    tailscale: '#E74C3C',
    lan: '#95A5A6',
    bg: '#F8FAFC',
    text: '#2C3E50',
    white: '#FFFFFF'
  };
  
  let svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + diagramW + '" height="' + diagramH + '" font-family="sans-serif">';
  svg += '<rect width="100%" height="100%" fill="' + colorScheme.bg + '"/>';
  
  // Title
  svg += '<text x="' + pad + '" y="30" font-size="14" font-weight="bold" fill="' + colorScheme.text + '">' + escapeLatex(options.title || 'Network Diagram') + '</text>';
  
  // Calculate node positions
  const nodePositions = {};
  for (const node of nodes) {
    const col = node.col || 0;
    const row = node.row || 0;
    const x = pad + col * (nodeW + gapX);
    const y = pad + 40 + row * (nodeH + gapY);
    nodePositions[node.id] = { x, y, node };
  }
  
  // Draw connections
  for (const conn of connections) {
    const from = nodePositions[conn.from];
    const to = nodePositions[conn.to];
    if (!from || !to) continue;
    
    const fromX = from.x + nodeW;
    const fromY = from.y + nodeH / 2;
    const toX = to.x;
    const toY = to.y + nodeH / 2;
    
    const midX = (fromX + toX) / 2;
    
    const color = conn.color || colorScheme.lan;
    const strokeW = conn.thick ? 3 : 1.5;
    
    // Arrow line
    svg += '<path d="M ' + fromX + ' ' + fromY + ' C ' + midX + ' ' + fromY + ', ' + midX + ' ' + toY + ', ' + toX + ' ' + toY + '" fill="none" stroke="' + color + '" stroke-width="' + strokeW + '"/>';
    
    // Arrow head
    const angle = Math.atan2(toY - fromY, toX - fromX);
    const arrowSize = 8;
    const ax = toX - arrowSize * Math.cos(angle - Math.PI / 6);
    const ay = toY - arrowSize * Math.sin(angle - Math.PI / 6);
    const ax2 = toX - arrowSize * Math.cos(angle + Math.PI / 6);
    const ay2 = toY - arrowSize * Math.sin(angle + Math.PI / 6);
    svg += '<polygon points="' + toX + ',' + toY + ' ' + ax + ',' + ay + ' ' + ax2 + ',' + ay2 + '" fill="' + color + '"/>';
    
    // Label
    if (conn.label) {
      svg += '<text x="' + midX + '" y="' + (Math.min(fromY, toY) - 5) + '" font-size="10" fill="' + color + '" text-anchor="middle">' + escapeLatex(conn.label) + '</text>';
    }
  }
  
  // Draw nodes
  for (const id in nodePositions) {
    const { x, y, node } = nodePositions[id];
    const bg = colorScheme[node.type] || colorScheme.server;
    
    // Shadow
    svg += '<rect x="' + (x+2) + '" y="' + (y+2) + '" width="' + nodeW + '" height="' + nodeH + '" fill="rgba(0,0,0,0.1)" rx="6"/>';
    // Node box
    svg += '<rect x="' + x + '" y="' + y + '" width="' + nodeW + '" height="' + nodeH + '" fill="' + bg + '" rx="6"/>';
    // Icon (simple text-based icon)
    const icon = node.icon || '';
    const labelLines = node.label.split('\n');
    let textY = y + nodeH / 2 - (labelLines.length - 1) * fontSize * 0.6;
    for (const line of labelLines) {
      svg += '<text x="' + (x + nodeW / 2) + '" y="' + textY + '" font-size="' + fontSize + '" font-weight="bold" fill="' + colorScheme.white + '" text-anchor="middle">' + escapeLatex(line) + '</text>';
      textY += fontSize * 1.3;
    }
  }
  
  svg += '</svg>';
  return svg;
}

function escapeLatex(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function parseNodes(text) {
  return text.split('\n').filter(l => l.trim()).map(line => {
    const [id, label, type, col, row, icon] = line.split('|').map(s => s.trim());
    return { id, label, type: type || 'server', col: parseInt(col) || 0, row: parseInt(row) || 0, icon };
  });
}

function parseConnections(text) {
  return text.split('\n').filter(l => l.trim()).map(line => {
    const [from, to, label, color] = line.split('|').map(s => s.trim());
    return { from, to, label, color: color || '#95A5A6' };
  });
}

const args = process.argv.slice(2);
let nodes = [], conns = [], title = 'Network Diagram';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--nodes' && args[i+1]) {
    nodes = parseNodes(args[++i]);
  } else if (args[i] === '--conns' && args[i+1]) {
    conns = parseConnections(args[++i]);
  } else if (args[i] === '--title' && args[i+1]) {
    title = args[++i];
  }
}

const svg = buildNetworkDiagram(nodes, conns, { title, fontSize: 11, nodeW: 130, nodeH: 50 });
const hash = crypto.createHash('sha256').update(JSON.stringify(nodes) + JSON.stringify(conns)).digest('hex').slice(0, 10);
const outDir = DEFAULT_OUTPUT_DIR;
fs.mkdirSync(outDir, { recursive: true });
const svgPath = path.join(outDir, 'diagram-' + hash + '.svg');
fs.writeFileSync(svgPath, svg);

const pngPath = svgPath.replace('.svg', '.png');
sharp(svgPath).png({ quality: 92 }).toFile(pngPath)
  .then(function() { console.log(JSON.stringify({ svg: svgPath, png: pngPath })); })
  .catch(function(e) { console.error('Error: ' + e.message); process.exit(1); });