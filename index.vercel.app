
```react
import React, { useState, useEffect, useRef } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, collection, addDoc, onSnapshot, query, serverTimestamp } from 'firebase/firestore';
import { Users, FileDown, QrCode, LogOut, Camera, CheckCircle, AlertCircle, Plus, Wallet, Search } from 'lucide-react';

// --- Firebase Initialization ---
const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : {};
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const appId = typeof __app_id !== 'undefined' ? __app_id : 'jimpitan-app';

export default function App() {
  const [user, setUser] = useState(null);
  const [role, setRole] = useState(null); // 'admin' atau 'petugas'
  const [petugasName, setPetugasName] = useState('');
  
  const [wargaList, setWargaList] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [toast, setToast] = useState({ show: false, msg: '', type: 'success' });

  // --- Auth Effect ---
  useEffect(() => {
    const initAuth = async () => {
      try {
        if (typeof __initial_auth_token !== 'undefined' && __initial_auth_token) {
          await signInWithCustomToken(auth, __initial_auth_token);
        } else {
          await signInAnonymously(auth);
        }
      } catch (error) {
        console.error("Auth error:", error);
      }
    };
    initAuth();

    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setIsLoading(false);
    });
    return () => unsubscribe();
  }, []);

  // --- Data Fetching Effect ---
  useEffect(() => {
    if (!user) return;

    const wargaRef = collection(db, 'artifacts', appId, 'public', 'data', 'warga');
    const transRef = collection(db, 'artifacts', appId, 'public', 'data', 'transactions');

    const unsubWarga = onSnapshot(wargaRef, (snapshot) => {
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      // Sort manually since complex queries are restricted
      data.sort((a, b) => a.nama.localeCompare(b.nama));
      setWargaList(data);
    }, (err) => console.error(err));

    const unsubTrans = onSnapshot(transRef, (snapshot) => {
      const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      data.sort((a, b) => b.timestamp - a.timestamp); // Sort by newest
      setTransactions(data);
    }, (err) => console.error(err));

    return () => {
      unsubWarga();
      unsubTrans();
    };
  }, [user]);

  const showToast = (msg, type = 'success') => {
    setToast({ show: true, msg, type });
    setTimeout(() => setToast({ show: false, msg: '', type: 'success' }), 3000);
  };

  const handleLogin = (selectedRole, nameInput) => {
    setRole(selectedRole);
    if (selectedRole === 'petugas') {
      setPetugasName(nameInput || 'Petugas 1');
    }
  };

  const handleLogout = () => {
    setRole(null);
    setPetugasName('');
  };

  if (isLoading) {
    return <div className="min-h-screen flex items-center justify-center bg-green-50 text-green-700">Memuat sistem...</div>;
  }

  return (
    <div className="min-h-screen bg-gray-50 text-gray-800 font-sans">
      {/* Toast Notification */}
      {toast.show && (
        <div className={`fixed top-4 left-1/2 transform -translate-x-1/2 z-50 px-4 py-2 rounded-full shadow-lg flex items-center space-x-2 text-white ${toast.type === 'success' ? 'bg-green-600' : 'bg-red-500'} transition-all`}>
          {toast.type === 'success' ? <CheckCircle size={20} /> : <AlertCircle size={20} />}
          <span className="font-medium">{toast.msg}</span>
        </div>
      )}

      {/* Routing State */}
      {!role ? (
        <LoginScreen onLogin={handleLogin} />
      ) : role === 'admin' ? (
        <AdminDashboard 
          wargaList={wargaList} 
          transactions={transactions} 
          onLogout={handleLogout} 
          showToast={showToast} 
        />
      ) : (
        <PetugasDashboard 
          wargaList={wargaList} 
          petugasName={petugasName} 
          onLogout={handleLogout} 
          showToast={showToast} 
        />
      )}
    </div>
  );
}

// ==========================================
// LOGIN SCREEN
// ==========================================
function LoginScreen({ onLogin }) {
  const [selectedRole, setSelectedRole] = useState('petugas');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const submitLogin = (e) => {
    e.preventDefault();
    // Simple mock validation for demo
    if (selectedRole === 'admin' && password === 'admin123') {
      onLogin('admin', 'Admin');
    } else if (selectedRole === 'petugas' && password === 'petugas123') {
      if (!name.trim()) {
        setError('Nama petugas harus diisi');
        return;
      }
      onLogin('petugas', name);
    } else {
      setError('Password salah! (Hint: admin123 / petugas123)');
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-4">
      <div className="w-full max-w-md bg-white p-8 rounded-2xl shadow-xl">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 bg-green-100 text-green-600 rounded-full flex items-center justify-center">
            <Wallet size={32} />
          </div>
        </div>
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-2">E-Jimpitan Desa</h1>
        <p className="text-center text-gray-500 mb-8">Sistem Pencatatan Keuangan Warga</p>

        {error && <div className="mb-4 p-3 bg-red-100 text-red-700 rounded-lg text-sm">{error}</div>}

        <form onSubmit={submitLogin} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Masuk Sebagai</label>
            <select 
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none"
              value={selectedRole}
              onChange={(e) => { setSelectedRole(e.target.value); setError(''); }}
            >
              <option value="petugas">Petugas Keliling</option>
              <option value="admin">Administrator</option>
            </select>
          </div>

          {selectedRole === 'petugas' && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Nama Petugas</label>
              <input 
                type="text" 
                placeholder="Misal: Budi"
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input 
              type="password" 
              placeholder={selectedRole === 'admin' ? "Masukkan admin123" : "Masukkan petugas123"}
              className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 outline-none"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <button 
            type="submit" 
            className="w-full bg-green-600 hover:bg-green-700 text-white font-bold py-3 px-4 rounded-lg transition duration-200"
          >
            Masuk
          </button>
        </form>
      </div>
    </div>
  );
}

// ==========================================
// ADMIN DASHBOARD
// ==========================================
function AdminDashboard({ wargaList, transactions, onLogout, showToast }) {
  const [activeTab, setActiveTab] = useState('warga'); // 'warga' atau 'laporan'
  
  // Warga Form State
  const [nama, setNama] = useState('');
  const [alamat, setAlamat] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleAddWarga = async (e) => {
    e.preventDefault();
    if (!nama || !alamat) return showToast('Harap isi semua data', 'error');
    setIsSubmitting(true);
    try {
      const wargaRef = collection(db, 'artifacts', appId, 'public', 'data', 'warga');
      await addDoc(wargaRef, {
        nama,
        alamat,
        createdAt: Date.now()
      });
      showToast('Data warga berhasil ditambahkan!');
      setNama('');
      setAlamat('');
    } catch (error) {
      showToast('Gagal menambah warga', 'error');
    }
    setIsSubmitting(false);
  };

  const downloadCSV = () => {
    if (transactions.length === 0) return showToast('Belum ada data transaksi', 'error');

    const headers = ["Tanggal", "Nama Warga", "Nominal (Rp)", "Petugas"];
    const rows = transactions.map(t => {
      const dateStr = new Date(t.timestamp).toLocaleString('id-ID');
      return `"${dateStr}","${t.wargaName}","${t.amount}","${t.petugasName}"`;
    });

    const csvContent = "data:text/csv;charset=utf-8," + headers.join(",") + "\n" + rows.join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `laporan_jimpitan_${new Date().getTime()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const totalJimpitan = transactions.reduce((acc, curr) => acc + Number(curr.amount), 0);

  return (
    <div className="pb-10">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-4 h-16 flex items-center justify-between">
          <div className="flex items-center space-x-2 text-green-700">
            <Users size={24} />
            <span className="font-bold text-lg">Panel Admin</span>
          </div>
          <button onClick={onLogout} className="flex items-center space-x-1 text-gray-500 hover:text-red-500">
            <LogOut size={18} />
            <span className="text-sm font-medium">Keluar</span>
          </button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 mt-6">
        {/* Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-white p-4 rounded-xl shadow-sm border-l-4 border-green-500">
            <p className="text-sm text-gray-500">Total Warga Terdaftar</p>
            <p className="text-2xl font-bold text-gray-800">{wargaList.length}</p>
          </div>
          <div className="bg-white p-4 rounded-xl shadow-sm border-l-4 border-blue-500">
            <p className="text-sm text-gray-500">Total Kas Jimpitan</p>
            <p className="text-2xl font-bold text-gray-800">Rp {totalJimpitan.toLocaleString('id-ID')}</p>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex space-x-2 mb-6 bg-gray-200 p-1 rounded-lg">
          <button 
            className={`flex-1 py-2 text-sm font-medium rounded-md transition ${activeTab === 'warga' ? 'bg-white shadow text-green-700' : 'text-gray-600 hover:bg-gray-300'}`}
            onClick={() => setActiveTab('warga')}
          >
            Data Warga
          </button>
          <button 
            className={`flex-1 py-2 text-sm font-medium rounded-md transition ${activeTab === 'laporan' ? 'bg-white shadow text-blue-700' : 'text-gray-600 hover:bg-gray-300'}`}
            onClick={() => setActiveTab('laporan')}
          >
            Laporan Jimpitan
          </button>
        </div>

        {/* Tab Content: Data Warga */}
        {activeTab === 'warga' && (
          <div className="space-y-6">
            <div className="bg-white p-5 rounded-xl shadow-sm">
              <h2 className="text-lg font-bold text-gray-800 mb-4 flex items-center"><Plus size={18} className="mr-2"/> Tambah Warga Baru</h2>
              <form onSubmit={handleAddWarga} className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-600 mb-1">Nama Lengkap</label>
                  <input type="text" value={nama} onChange={(e) => setNama(e.target.value)} className="w-full p-2 border rounded-lg outline-none focus:border-green-500" placeholder="Misal: Bapak Supardi" />
                </div>
                <div>
                  <label className="block text-sm text-gray-600 mb-1">Alamat / RT</label>
                  <input type="text" value={alamat} onChange={(e) => setAlamat(e.target.value)} className="w-full p-2 border rounded-lg outline-none focus:border-green-500" placeholder="Misal: RT 01 / RW 02" />
                </div>
                <div className="md:col-span-2">
                  <button type="submit" disabled={isSubmitting} className="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded-lg font-medium transition disabled:opacity-50">
                    {isSubmitting ? 'Menyimpan...' : 'Simpan Data'}
                  </button>
                </div>
              </form>
            </div>

            <div className="bg-white rounded-xl shadow-sm overflow-hidden">
              <div className="p-4 bg-gray-50 border-b">
                <h2 className="font-bold text-gray-800">Daftar Warga & QR Code</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-gray-100 text-gray-600 text-sm">
                      <th className="p-3">Nama</th>
                      <th className="p-3">Alamat</th>
                      <th className="p-3 text-center">QR Code</th>
                    </tr>
                  </thead>
                  <tbody>
                    {wargaList.map((w) => (
                      <tr key={w.id} className="border-b hover:bg-gray-50">
                        <td className="p-3 font-medium">{w.nama}</td>
                        <td className="p-3 text-gray-500 text-sm">{w.alamat}</td>
                        <td className="p-3 flex justify-center">
                          <img 
                            src={`https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${w.id}`} 
                            alt="QR" 
                            className="w-16 h-16 border rounded bg-white p-1"
                            title={`ID: ${w.id}`}
                          />
                        </td>
                      </tr>
                    ))}
                    {wargaList.length === 0 && (
                      <tr><td colSpan="3" className="p-6 text-center text-gray-500">Belum ada data warga</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Tab Content: Laporan */}
        {activeTab === 'laporan' && (
          <div className="bg-white rounded-xl shadow-sm overflow-hidden">
            <div className="p-4 bg-gray-50 border-b flex justify-between items-center">
              <h2 className="font-bold text-gray-800">Riwayat Pemasukan</h2>
              <button onClick={downloadCSV} className="flex items-center space-x-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition">
                <FileDown size={16} />
                <span>Unduh CSV</span>
              </button>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-gray-100 text-gray-600 text-sm">
                    <th className="p-3">Waktu</th>
                    <th className="p-3">Warga</th>
                    <th className="p-3">Nominal</th>
                    <th className="p-3">Petugas</th>
                  </tr>
                </thead>
                <tbody>
                  {transactions.map((t) => (
                    <tr key={t.id} className="border-b hover:bg-gray-50 text-sm">
                      <td className="p-3 text-gray-500">{new Date(t.timestamp).toLocaleString('id-ID', {day:'numeric', month:'short', hour:'2-digit', minute:'2-digit'})}</td>
                      <td className="p-3 font-medium">{t.wargaName}</td>
                      <td className="p-3 text-green-600 font-bold">Rp {Number(t.amount).toLocaleString('id-ID')}</td>
                      <td className="p-3">{t.petugasName}</td>
                    </tr>
                  ))}
                  {transactions.length === 0 && (
                    <tr><td colSpan="4" className="p-6 text-center text-gray-500">Belum ada transaksi</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

// ==========================================
// PETUGAS DASHBOARD (MOBILE FOCUSED)
// ==========================================
function PetugasDashboard({ wargaList, petugasName, onLogout, showToast }) {
  const [scannedWarga, setScannedWarga] = useState(null);
  const [amount, setAmount] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showManualSelect, setShowManualSelect] = useState(false);

  // Simulasi Scan (Mencari warga berdasarkan ID)
  const handleScanSimulation = (wargaId) => {
    const found = wargaList.find(w => w.id === wargaId);
    if (found) {
      setScannedWarga(found);
      showToast(`QR Code Terdeteksi: ${found.nama}`);
      setShowManualSelect(false);
    } else {
      showToast('QR Code tidak dikenali!', 'error');
    }
  };

  const handleSimpanJimpitan = async (e) => {
    e.preventDefault();
    if (!amount || Number(amount) <= 0) return showToast('Masukkan nominal yang valid', 'error');
    
    setIsSubmitting(true);
    try {
      const transRef = collection(db, 'artifacts', appId, 'public', 'data', 'transactions');
      await addDoc(transRef, {
        wargaId: scannedWarga.id,
        wargaName: scannedWarga.nama,
        amount: Number(amount),
        petugasName: petugasName,
        timestamp: Date.now()
      });
      showToast(`Berhasil mencatat Rp ${Number(amount).toLocaleString('id-ID')} dari ${scannedWarga.nama}`);
      setScannedWarga(null);
      setAmount('');
    } catch (error) {
      showToast('Gagal menyimpan data', 'error');
    }
    setIsSubmitting(false);
  };

  return (
    <div className="flex flex-col min-h-screen max-w-md mx-auto bg-white shadow-xl">
      {/* Header */}
      <header className="bg-green-600 text-white p-4 sticky top-0 z-10 shadow-md">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="font-bold text-lg">Input Jimpitan</h1>
            <p className="text-xs text-green-100">Petugas: {petugasName}</p>
          </div>
          <button onClick={onLogout} className="p-2 bg-green-700 rounded-full hover:bg-green-800 transition">
            <LogOut size={18} />
          </button>
        </div>
      </header>

      <main className="flex-1 p-4 bg-gray-50 overflow-y-auto">
        {!scannedWarga ? (
          <div className="space-y-6 flex flex-col items-center justify-center pt-8">
            <div className="w-full bg-white p-6 rounded-2xl shadow-sm text-center border-2 border-dashed border-gray-300">
              <QrCode size={64} className="mx-auto text-gray-400 mb-4" />
              <h2 className="text-lg font-bold text-gray-700 mb-2">Scan QR Code Warga</h2>
              <p className="text-sm text-gray-500 mb-6">Arahkan kamera ke QR code yang menempel di rumah warga.</p>
              
              <button 
                onClick={() => setShowManualSelect(!showManualSelect)}
                className="w-full flex items-center justify-center space-x-2 bg-gray-100 text-gray-700 py-3 rounded-xl font-medium hover:bg-gray-200 transition"
              >
                <Camera size={20} />
                <span>Simulasi Scan Kamera</span>
              </button>
            </div>

            {/* Fallback Simulasi Pilihan Manual untuk Lingkungan Preview */}
            {showManualSelect && (
              <div className="w-full bg-white p-4 rounded-xl shadow-sm animate-fade-in">
                <p className="text-xs text-orange-600 mb-3 text-center bg-orange-50 p-2 rounded">
                  *Karena limitasi kamera pada preview web, gunakan pilihan manual ini sebagai simulasi scan QR.
                </p>
                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {wargaList.map(w => (
                    <button 
                      key={w.id}
                      onClick={() => handleScanSimulation(w.id)}
                      className="w-full text-left p-3 border rounded-lg hover:border-green-500 hover:bg-green-50 transition flex justify-between items-center"
                    >
                      <div>
                        <div className="font-medium text-gray-800">{w.nama}</div>
                        <div className="text-xs text-gray-500">{w.alamat}</div>
                      </div>
                      <QrCode size={16} className="text-green-500" />
                    </button>
                  ))}
                  {wargaList.length === 0 && <p className="text-center text-sm text-gray-500">Belum ada data warga terdaftar.</p>}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="space-y-4 pt-4">
            <button 
              onClick={() => setScannedWarga(null)}
              className="text-sm text-gray-500 flex items-center space-x-1 hover:text-gray-800"
            >
              <span>← Batal / Scan Ulang</span>
            </button>

            <div className="bg-white p-5 rounded-2xl shadow-sm border border-green-100">
              <div className="flex items-center space-x-4 mb-4 pb-4 border-b">
                <div className="w-12 h-12 bg-green-100 text-green-600 rounded-full flex items-center justify-center">
                  <Users size={24} />
                </div>
                <div>
                  <h2 className="text-lg font-bold text-gray-800">{scannedWarga.nama}</h2>
                  <p className="text-sm text-gray-500">{scannedWarga.alamat}</p>
                </div>
              </div>

              <form onSubmit={handleSimpanJimpitan}>
                <div className="mb-6">
                  <label className="block text-sm font-medium text-gray-700 mb-2">Nominal Uang (Rp)</label>
                  <div className="relative">
                    <span className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-500 font-bold">Rp</span>
                    <input 
                      type="number" 
                      className="w-full p-4 pl-12 text-xl font-bold border-2 border-gray-200 rounded-xl outline-none focus:border-green-500 focus:ring-4 focus:ring-green-100 transition"
                      placeholder="0"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      autoFocus
                    />
                  </div>
                  {/* Preset Nominal */}
                  <div className="flex space-x-2 mt-3">
                    {[500, 1000, 2000].map(val => (
                      <button
                        type="button"
                        key={val}
                        onClick={() => setAmount(val.toString())}
                        className="flex-1 py-2 bg-gray-100 text-gray-700 font-medium rounded-lg text-sm hover:bg-gray-200"
                      >
                        {val}
                      </button>
                    ))}
                  </div>
                </div>

                <button 
                  type="submit" 
                  disabled={isSubmitting}
                  className="w-full flex items-center justify-center space-x-2 bg-green-600 hover:bg-green-700 text-white py-4 rounded-xl font-bold text-lg transition disabled:opacity-50"
                >
                  <CheckCircle size={24} />
                  <span>{isSubmitting ? 'Menyimpan...' : 'Simpan Transaksi'}</span>
                </button>
              </form>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

```
