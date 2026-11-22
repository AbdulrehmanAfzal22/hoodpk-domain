import React from 'react';
import {createRoot} from 'react-dom/client';
import {useEffect,useRef,useState} from 'react';
import {useLocation} from 'react-router-dom';
import {BrowserRouter} from 'react-router-dom';
import {AnimatePresence,LayoutGroup} from 'framer-motion';
import {Toaster} from 'sonner';
import {SessionProvider} from './context/SessionContext';
import FloatingSupportButton from './components/FloatingSupportButton';
import CursorProvider from './components/CursorProvider';
import AppRoutes from './routes/AppRoutes';
import AuthCallback from './pages/AuthCallback';
import {initialAuthRedirect} from './lib/supabase';
import './styles/base.css';
import './styles/workflows.css';
import './styles/luxury-home.css';
import './styles/luxury-mobile.css';
import './styles/luxury-footer.css';
import './styles/homepage.css';
import './styles/theme.css';
import './styles/support-requests.css';
import './styles/collection-browsing.css';
import './styles/dark-theme.css';
import './styles/hood-sections.css';
import './styles/hood-card-fixes.css';
import './styles/hood-campaign.css';

// Preserve old prototype bookmarks while moving to real routes.
if(['#home','#shop','#admin','#account'].includes(location.hash)){history.replaceState(null,'',location.hash==='#home'?'/':location.hash.slice(1));}

function App(){
  return (
    <BrowserRouter>
      <CursorProvider>
        <SessionProvider>
          <RouteTransitions/>
          <FloatingSupportButton/>
          <Toaster richColors position="bottom-right"/>
        </SessionProvider>
      </CursorProvider>
    </BrowserRouter>
  );
}

function RouteTransitions(){
  const location=useLocation();
  const [incomingLink,setIncomingLink]=useState(()=>
    initialAuthRedirect?.shouldHandle&&/^\/(?:login|register|auth|reset-password)?\/?$/i.test(location.pathname)?initialAuthRedirect:null
  );
  const finishIncomingLink=useRef(()=>setIncomingLink(null)).current;
  const initialRender=useRef(true);
  useEffect(()=>{
    if(initialRender.current){initialRender.current=false;return undefined;}
    const timer=window.setTimeout(()=>{const target=location.hash?document.getElementById(location.hash.slice(1)):null;target?target.scrollIntoView({behavior:'smooth'}):window.scrollTo(0,0);},location.pathname.startsWith('/admin')?0:450);
    return()=>window.clearTimeout(timer);
  },[location.pathname,location.hash]);
  if(incomingLink)return <AuthCallback link={incomingLink} onComplete={finishIncomingLink}/>;
  return <LayoutGroup id="maison-elan-routes"><AnimatePresence mode="popLayout" initial={false}><AppRoutes key={location.pathname} location={location}/></AnimatePresence></LayoutGroup>;
}

createRoot(document.getElementById('root')).render(<App/>);
