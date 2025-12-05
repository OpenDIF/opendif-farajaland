import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthProvider';
import Home from './pages/Home';
import Login from './pages/Login';
import Apply from './pages/Apply';
import Status from './pages/Status';
import Success from './pages/Success';
import GovPay from './pages/GovPay';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Login />} />
          <Route path="/apply" element={<Apply />} />
          <Route path="/status" element={<Status />} />
          <Route path="/success" element={<Success />} />
          <Route path="/govpay" element={<GovPay />} />
        </Routes>
      </Router>
    </AuthProvider>
  );
}

export default App;
