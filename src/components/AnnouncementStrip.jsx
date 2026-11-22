import './AnnouncementStrip.css';

const announcements=[
 'Delivery across Pakistan · Rs. 300',
 'Custom hoodies & T-shirts',
 'Everyday plain hoodies',
 'Zip-up hoodies & sweatshirts',
 'Printed styles',
 'Combo deals',
];

export default function AnnouncementStrip(){
 return <aside className="hood-announcement" aria-label="Store announcements">
  <div className="hood-announcement__track">
   {[0,1].map(copy=><ul className="hood-announcement__group" key={copy} aria-hidden={copy===1?true:undefined}>
    {announcements.map(message=><li key={message}>{message}</li>)}
   </ul>)}
  </div>
 </aside>;
}
