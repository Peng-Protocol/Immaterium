## Directory Map

```
./
├── index.html
├── js/
│   ├── app.js
│   ├── logic.js
│   ├── alpinejs-3.12.0.min.js
│   ├── bootstrap-5.3.3.bundle.min.js
│   ├── qrcode.min.js
├── css/
│   ├── bootstrap-5.3.3.min.css
├── assets/
│   ├── placeholderLogo.webp
```

### Local Dependencies
- **Alpine.js**: `js/alpinejs-3.12.0.min.js` (v3.12.0)
- **Bootstrap 5 CSS**: `css/bootstrap-5.3.3.min.css` (v5.3.3)
- **Bootstrap 5 JS**: `js/bootstrap-5.3.3.bundle.min.js` (v5.3.3)
- **QRCode.js**: `js/qrcode.min.js` (v1.4.4)
- **Polygon Logo**: `assets/matic-logo-1.webp`
- **Ethereum Provider**: Relies on `window.ethereum` (e.g., MetaMask)

**Note**: Download dependencies and place in specified paths:
- Alpine.js: `https://cdn.jsdelivr.net/npm/alpinejs@3.12.0/dist/cdn.min.js`
- Bootstrap CSS: `https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css`
- Bootstrap JS: `https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js`
- QRCode.js: `https://cdnjs.cloudflare.com/ajax/libs/qrcode.js/1.4.4/qrcode.min.js`

## Overview

Single-page web app using Alpine.js for reactive UI and Bootstrap 5 for styling, with all CSS inline in `index.html`. Features wallet connection via Ethereum provider (e.g., MetaMask), light/dark mode toggling, and modals for wallet connection and QR code generation.

### Key Features
- **Wallet Connection**: Connects to Ethereum wallet, displays address, updates UI based on chain ID.
- **Light/Dark Mode**: Toggles themes, respects system preferences, persists via `localStorage`.
- **Modals**: Bootstrap modals for wallet connection, QR code display, and disconnection.
- **Blockchain Interaction**: Handled in `logic.js` with function selectors for smart contract calls.

## CSS and Styling

All styles are inline in `index.html` within a `<style>` tag. Key elements:

- **Bootstrap Classes**:
  - `navbar`, `navbar-brand`, `nav-link` for navigation
  - `btn`, `btn-primary`, `btn-outline-light` for buttons
  - `modal`, `modal-dialog`, `modal-content` for modals
  - `form-control` for inputs
  - `d-none`, `show` for visibility
- **Inline CSS**:
  - `body`: `font-family: sans-serif; min-height: 100vh`
  - `.dark-mode`: `background: #212121; color: #f5f5f5`
  - `.modal-content`: `border-radius: 8px`, `background-color: #fff` (light) or `#333` (dark)
  - `.btn`: `min-width: 100px; padding: 10px` for touch-friendly interaction
  - `#qrCanvas`: `margin: auto` for centering
  - `#dispenserCost`: `font-weight: bold` for cost display
  - `#dispenserError`: `color: red; display: none` for error messages
- **Icons and Images**:
  - Emoji buttons (🌙, 🌞, 🌐) for mode toggle and network
  - Polygon logo (`assets/matic-logo-1.webp`) for chain ID
- **Responsive Design**:
  - Bootstrap grid for mobile compatibility
  - Buttons use `min-width: 100px`, `padding: 10px` for touch support

**Code Snippet: Inline CSS**
```css
body {
    font-family: sans-serif;
    min-height: 100vh;
}
.dark-mode {
    background: #212121;
    color: #f5f5f5;
}
.modal-content {
    border-radius: 8px;
}
.dark-mode .modal-content {
    background-color: #333;
}
.btn {
    min-width: 100px;
    padding: 10px;
}
#qrCanvas {
    margin: auto;
}
#sampleBlockchainInfo {
    font-weight: bold;
}
#sampleBlockchainError {
    color: red;
    display: none;
}
```

### Animations
No custom CSS animations. Bootstrap modals use built-in `fade` transitions.

## Light/Dark Mode Functionality

Toggles light/dark themes, respects system preferences, persists in `localStorage`.

- **Initialization**: Checks `localStorage` or `prefers-color-scheme: dark`.
- **Toggling**: Switches `.dark-mode` class, updates button emoji.
- **Persistence**: Saves to `localStorage`.

**Code Snippet: Light/Dark Mode Logic**
```javascript
// js/app.js
function initializeMode() {
    const savedMode = localStorage.getItem('isDarkMode');
    const isDarkMode = savedMode === null ? window.matchMedia('(prefers-color-scheme: dark)').matches : savedMode === 'true';
    applyMode(isDarkMode);
}

function toggleDarkMode() {
    const currentMode = document.body.classList.contains('dark-mode');
    applyMode(!currentMode);
}

function applyMode(isDarkMode) {
    document.body.classList.toggle('dark-mode', isDarkMode);
    const button = document.getElementById('modeToggle');
    if (button) button.textContent = isDarkMode ? '🌞' : '🌙';
    localStorage.setItem('isDarkMode', isDarkMode);
}
```

**State Management**:
- **Initial State**: `isDarkMode: boolean` (from `localStorage` or system)
- **Session State**: Updated on toggle, applied to `document.body.classList`
- **Cache State**: Persisted in `localStorage` as `'isDarkMode'`

## Wallet Connection Functionality

Connects to Ethereum wallet, displays address, updates UI. Network settings are a placeholder.

- **Connection**: Uses `eth_requestAccounts` to set `walletAddress` and `chainId`.
- **UI Updates**: Shows truncated address on connect button.
- **Network Handling**: Placeholder function.
- **Disconnection**: Resets state and UI.

**Code Snippet: Wallet Connection Logic**
```javascript
// js/app.js
async function connectToWallet() {
    const connectButton = document.getElementById('connectWallet');
    connectButton.disabled = true;
    connectButton.textContent = 'Connecting...';
    try {
        const walletData = await window.web3Logic.connectWallet();
        if (walletData.address) {
            connectButton.textContent = `${walletData.address.slice(0, 6)}...${walletData.address.slice(-4)}`;
            connectButton.classList.add('connected');
            document.getElementById('walletModal').classList.remove('show');
            // Placeholder: Update network button based on chainId
        } else if (window.web3Logic.error) {
            alert(window.web3Logic.error);
        }
    } catch (err) {
        console.error('Connect wallet failed:', err);
        alert('Failed to connect wallet.');
    } finally {
        connectButton.disabled = false;
        if (!window.web3Logic.walletAddress) connectButton.textContent = 'Connect Wallet';
    }
}

// js/logic.js
async connectWallet() {
    if (typeof window.ethereum !== 'undefined') {
        try {
            const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            this.walletAddress = accounts[0];
            this.chainId = await window.ethereum.request({ method: 'eth_chainId' });
            this.rpcUrl = window.ethereum.rpcUrl || 'unknown';
            this.error = null;
            window.ethereum.on('accountsChanged', (accounts) => { this.walletAddress = accounts[0] || null; });
            window.ethereum.on('chainChanged', (newChainId) => { 
                this.chainId = newChainId; 
                window.dispatchEvent(new Event('chainChanged')); 
            });
        } catch (err) {
            this.error = 'Failed to connect wallet: ' + err.message;
        }
    } else {
        this.error = 'No Ethereum provider detected.';
    }
    return { address: this.walletAddress, chainId: this.chainId, rpcUrl: this.rpcUrl };
}
```

**Code Snippet: Network Placeholder**
```javascript
// js/app.js
function updateNetworkButton(chainId) {
    // Placeholder: Implement network-specific UI updates
    const networkButton = document.getElementById('networkSettings');
    networkButton.textContent = '🌐';
}

function handleNetworkSwitch() {
    // Placeholder: Implement network switching logic
    alert('Network switching not implemented.');
}
```

**State Management**:
- **Initial State**:
  - `walletAddress: string | null`
  - `chainId: string | null`
  - `rpcUrl: string | null`
  - `error: string | null`
- **Session State**: Updated on connect, disconnect, or chain change
- **Cache State**: None

## QR Code Generation

Generates QR codes for Ethereum addresses or a fallback URL using QRCode.js, with URI copying functionality.

**Code Snippet: QR Code and Copy Logic**
```javascript
// js/app.js
function generateQRCode() {
    document.getElementById('qrError').style.display = 'none';
    const inputAddress = document.getElementById('qrAddress').value.trim();
    let uri;
    if (inputAddress) {
        if (/^0x[a-fA-F0-9]{40}$/.test(inputAddress)) {
            uri = `ethereum:${inputAddress}@137`;
        } else {
            showQRError('Invalid Ethereum address.');
            return;
        }
    } else if (window.web3Logic.walletAddress) {
        uri = `ethereum:${window.web3Logic.walletAddress}@137`;
    } else {
        uri = 'https://link.dexhune.eth.limo';
    }
    const canvas = document.getElementById('qrCanvas');
    QRCode.toCanvas(canvas, uri, { width: 300 }, (err) => {
        if (err) {
            console.error('QR Code failed:', err);
            showQRError('QR Code generation failed.');
        } else {
            document.getElementById('copyUri').style.display = 'block';
        }
    });
}

function copyURI() {
    const inputAddress = document.getElementById('qrAddress').value.trim();
    let uri;
    if (inputAddress) {
        if (/^0x[a-fA-F0-9]{40}$/.test(inputAddress)) {
            uri = `ethereum:${inputAddress}@137`;
        } else {
            uri = 'https://link.dexhune.eth.limo';
        }
    } else if (window.web3Logic.walletAddress) {
        uri = `ethereum:${window.web3Logic.walletAddress}@137`;
    } else {
        uri = 'https://link.dexhune.eth.limo';
    }
    navigator.clipboard.writeText(uri).then(() => {
        alert('URI copied: ' + uri);
    }).catch(err => {
        console.error('Copy URI failed:', err);
        alert('Copy failed.');
    });
}
```

**State Management**:
- **Initial State**: `inputAddress: string`, `uri: string`
- **Session State**: Updated on input change or wallet connection
- **Cache State**: None

## Template Guidelines

To create a similar app:
1. **Setup Dependencies**:
   - Place dependencies in `js/` and `css/` as specified.
   - Ensure `window.ethereum` is available (e.g., MetaMask).
2. **Structure HTML**:
   - Include inline CSS in `<style>` tag, with cost and error styles.
   - Use Bootstrap navbar and modals with Alpine.js (`x-data`, `x-on`).
3. **Implement Wallet Connection**:
   - Use `eth_requestAccounts` and `eth_chainId`.
   - Handle `accountsChanged` and `chainChanged` events.
4. **Add Light/Dark Mode**:
   - Toggle `.dark-mode` class, persist in `localStorage`.
   - Use system preference detection.
5. **Blockchain Integration**:
   - Define contract addresses and function selectors in `logic.js`.
   - Use `eth_call` for view functions, `eth_sendTransaction` for state changes.
6. **Ensure Mobile Compatibility**:
   - Use Bootstrap’s responsive classes.
   - Ensure buttons have `min-width: 100px`, `padding: 10px`.
7. **Load Order**:
   - Load scripts unconditionally in `index.html` (e.g., `<script src="./js/alpinejs-3.12.0.min.js" defer></script>`).
   - Use `defer` for Alpine.js initialization.
