const hasSupabase = window.SUPABASE_URL && !window.SUPABASE_URL.startsWith("YOUR_") && window.SUPABASE_PUBLISHABLE_KEY && !window.SUPABASE_PUBLISHABLE_KEY.startsWith("YOUR_");
const sb = hasSupabase && window.supabase ? window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_PUBLISHABLE_KEY) : null;

const demoProperties=[
 {id:"demo-1",title:"خانه ۳ اتاقه در کارته چهار",province:"کابل",district:"کارته چهار",category:"خانه",deal_type:"rent",price:15000,unit:"ماهانه",area:180,rooms:3,status:"active",description:"خانه مناسب خانواده با دسترسی خوب به جاده اصلی.",image_url:"https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=900&q=80"},
 {id:"demo-2",title:"آپارتمان دو اتاقه در مکروریان",province:"کابل",district:"مکروریان",category:"آپارتمان",deal_type:"rent",price:18000,unit:"ماهانه",area:120,rooms:2,status:"active",description:"آپارتمان روشن و مناسب خانواده.",image_url:"https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=900&q=80"},
 {id:"demo-3",title:"خانه فروشی در خوشحال خان",province:"کابل",district:"خوشحال خان",category:"خانه",deal_type:"sale",price:3000000,unit:"افغانی",area:240,rooms:4,status:"active",description:"خانه با حیاط و پارکینگ.",image_url:"https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=80"}
];
function money(n){return new Intl.NumberFormat("fa-AF").format(Number(n)||0)}
function esc(s){return String(s??"").replace(/[&<>"']/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[m]))}
function card(p){
 return `<article class="property-card"><img src="${esc(p.image_url||"https://images.unsplash.com/photo-1560185008-b033106af5c3?auto=format&fit=crop&w=900&q=80")}" alt="${esc(p.title)}"><div class="property-body"><span class="badge">${p.deal_type==="rent"?"کرایی":"فروشی"}</span><h3>${esc(p.title)}</h3><div class="meta">📍 ${esc(p.province)}، ${esc(p.district)} · 🛏️ ${esc(p.rooms||"-")} اتاق · 📐 ${esc(p.area||"-")} متر</div><div class="price">${money(p.price)} ${p.unit==="ماهانه"?"افغانی / ماه":"افغانی"}</div><a class="btn btn-light" href="property.html?id=${encodeURIComponent(p.id)}">مشاهده جزئیات</a></div></article>`
}
async function getProperties(filters={}){
 if(!sb) return demoProperties.filter(p=>(!filters.province||p.province===filters.province)&&(!filters.district||p.district.includes(filters.district))&&(!filters.type||p.deal_type===filters.type)&&(!filters.category||p.category===filters.category));
 let q=sb.from("properties").select("*").eq("status","active").order("created_at",{ascending:false});
 if(filters.province) q=q.eq("province",filters.province); if(filters.district) q=q.ilike("district",`%${filters.district}%`); if(filters.type) q=q.eq("deal_type",filters.type); if(filters.category) q=q.eq("category",filters.category);
 const {data,error}=await q; if(error){console.error(error);return []} return data||[];
}
async function loadFeatured(){
 const el=document.getElementById("featured"); if(!el)return;
 const data=await getProperties({}); el.innerHTML=data.slice(0,6).map(card).join("")||'<div class="empty">هنوز ملکی ثبت نشده است.</div>';
}
async function currentUser(){if(!sb)return null; const {data}=await sb.auth.getUser(); return data.user||null}
function requireConfig(){if(!sb){alert("ابتدا SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY را در assets/js/config.js تنظیم کنید.");return false}return true}
async function signOut(){if(sb) await sb.auth.signOut(); location.href="../index.html"}
