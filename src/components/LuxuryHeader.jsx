import {useCallback,useEffect,useRef,useState} from 'react';
import {Menu,X} from 'lucide-react';
import {Link} from 'react-router-dom';
import BrandLogo from './BrandLogo';
import DesktopNav from './DesktopNav';
import HeaderActions from './HeaderActions';
import MobileMenu from './MobileMenu';
import IconButton from './common/IconButton';
import './LuxuryHeader.css';

export default function LuxuryHeader({home=false}){
  const [open,setOpen]=useState(false);
  const [scrolled,setScrolled]=useState(false);
  const menuButtonRef=useRef(null);
  const close=useCallback(()=>setOpen(false),[]);
  const closeAndRestoreFocus=useCallback(()=>{setOpen(false);window.requestAnimationFrame(()=>menuButtonRef.current?.focus());},[]);
  const toggleMenu=()=>{
    if(open){setOpen(false);return;}
    setOpen(true);
    window.setTimeout(()=>{
      const drawer=document.querySelector('.luxury-header__drawer[data-open="true"]');
      drawer?.querySelector('button')?.focus();
    },0);
  };

  useEffect(()=>{
    if(!home){setScrolled(false);return;}
    const announcement=document.querySelector('.hood-announcement');
    const update=()=>setScrolled(window.scrollY>=(announcement?.offsetHeight||35));
    update();
    window.addEventListener('scroll',update,{passive:true});
    window.addEventListener('resize',update);
    return()=>{
      window.removeEventListener('scroll',update);
      window.removeEventListener('resize',update);
    };
  },[home]);

  const className=['luxury-header',home&&!scrolled?'luxury-header--overlay':'',scrolled?'luxury-header--scrolled':''].filter(Boolean).join(' ');
  return <>
    <header className={className}>
      <div className="luxury-header__bar">
        <IconButton ref={menuButtonRef} className="luxury-header__menu-toggle" type="button" label={open?'Close navigation menu':'Open navigation menu'} aria-expanded={open} aria-controls="luxury-mobile-menu" onClick={toggleMenu} icon={open?<X size={22} strokeWidth={1.5}/>:<Menu size={22} strokeWidth={1.5}/>} />
        <Link className="luxury-header__wordmark" to="/" aria-label="the HOOD home"><BrandLogo/></Link>
        <DesktopNav/>
        <HeaderActions/>
      </div>
    </header>
    <MobileMenu open={open} onClose={closeAndRestoreFocus}/>
  </>;
}