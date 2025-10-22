import streamlit as st
import json
import requests
import pandas as pd

# تنظیمات اولیه صفحه
st.set_page_config(
    page_title="پیشنهاد دهنده هوشمند تگ",
    page_icon="🏷️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# استایل‌های پیشرفته‌تر با فونت فارسی
st.markdown("""
    <style>
    @import url('https://fonts.googleapis.com/css2?family=Vazirmatn:wght@100..900&display=swap');
    
    * {
        font-family: 'Vazirmatn', sans-serif !important;
    }
    
    .main {
        direction: rtl;
        text-align: right;
    }
    
    /* بهبود استایل دکمه‌ها */
    .stButton > button {
        border-radius: 8px;
        padding: 10px 20px;
        font-weight: 500;
        transition: all 0.3s ease;
        border: none;
    }
    
    .stButton > button:hover {
        transform: translateY(-2px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    }
    
    /* بهبود استایل inputها */
    .stTextInput input, .stTextArea textarea {
        border-radius: 8px;
        padding: 12px;
        border: 2px solid #e1e5e9;
        transition: border-color 0.3s ease;
    }
    
    .stTextInput input:focus, .stTextArea textarea:focus {
        border-color: #4285f4;
        box-shadow: 0 0 0 2px rgba(66, 133, 244, 0.2);
    }
    
    /* کارت‌های مدرن */
    .custom-card {
        background: white;
        padding: 20px;
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        border: 1px solid #e1e5e9;
        margin-bottom: 20px;
    }
    
    /* هدر زیبا */
    .main-header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        border-radius: 12px;
        margin-bottom: 30px;
        text-align: center;
    }
    
    /* تگ‌های زیبا */
    .tag-chip {
        display: inline-block;
        background: #e3f2fd;
        color: #1976d2;
        padding: 6px 12px;
        border-radius: 20px;
        margin: 4px;
        font-size: 14px;
        border: 1px solid #bbdefb;
    }
    
    .tag-chip.primary {
        background: #e8f5e8;
        color: #2e7d32;
        border-color: #c8e6c9;
    }
    
    .tag-chip.secondary {
        background: #fff3e0;
        color: #ef6c00;
        border-color: #ffe0b2;
    }
    
    /* جدول بهبود یافته */
    .dataframe {
        width: 100%;
        border-collapse: collapse;
    }
    
    .dataframe th {
        background: #f8f9fa;
        padding: 12px;
        font-weight: 600;
        border-bottom: 2px solid #dee2e6;
    }
    
    .dataframe td {
        padding: 12px;
        border-bottom: 1px solid #dee2e6;
    }
    
    /* نوار کناری */
    .css-1d391kg {
        background: #f8f9fa;
    }
    </style>
""", unsafe_allow_html=True)

# توابع کمکی برای تعامل با API (بدون تغییر)
def suggest_tags_from_api(article_content, all_tags, api_key):
    if not api_key:
        raise ValueError("کلید API یافت نشد. لطفاً آن را وارد کنید.")
    
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    headers = {"Content-Type": "application/json"}
    system_instruction = """
    شما یک دستیار هوشمند متخصص در تحلیل معنایی متون و دسته‌بندی محتوا هستید. وظیفه شما درک عمیق مفهوم اصلی یک متن و انتخاب دقیق‌ترین برچسب‌ها (تگ‌ها) از یک لیست مشخص و همچنین تعیین سطح ارتباط هرکدام است.
    """
    user_prompt = f"""
    وظیفه:
    بر اساس "متن مقاله" زیر، مرتبط‌ترین و دقیق‌ترین تگ‌ها را از "لیست تگ‌های مجاز" انتخاب کرده، سطح ارتباط هرکدام را مشخص کن و یک امتیاز ارتباط به آن بده.

    قوانین مهم:
    1. **تحلیل مفهومی:** ابتدا مفهوم اصلی، موضوعات کلیدی و موجودیت‌های (افراد, مکان‌ها, مفاهیم) داخل "متن مقاله" را به دقت تحلیل کن.
    2. **تطبیق معنایی:** فقط تگ‌هایی را انتخاب کن که معنای آن‌ها مستقیماً با مفهوم اصلی متن مقاله همخوانی دارد.
    3. **تعیین سطح ارتباط:** برای هر تگ انتخاب شده، سطح ارتباط آن را از بین سه گزینه زیر مشخص کن:
        - 'ارتباط اصلی': تگ‌هایی که مستقیماً به موضوع اصلی و مرکزی متن اشاره دارند.
        - 'ارتباط ثانویه': تگ‌هایی که به موضوعات جانبی اما مهم متن مرتبط هستند.
        - 'ارتباط کلی': تگ‌هایی که زمینه کلی و گسترده‌تر متن را پوشش می‌دهند.
    4. **تخصیص امتیاز:** برای هر تگ، یک امتیاز عددی (score) بین ۱ تا ۱۰۰ تعیین کن که نشان‌دهنده میزان اطمینان تو از ارتباط آن تگ است. ۱۰۰ به معنای بیشترین ارتباط است.
    5. **رعایت لیست:** انتخاب‌های شما باید **منحصراً** از "لیست تگ‌های مجاز" باشد.
    6. **اولویت با ارتباط:** اگر هیچ تگ مرتبطی در لیست پیدا نکردی، یک آرایه خالی برگردان.
    7. **تعداد:** بین ۳ تا ۷ تگ که بیشترین ارتباط را دارند، پیشنهاد بده.

    لیست تگ‌های مجاز:
    ---
    {all_tags}
    ---

    متن مقاله:
    ---
    {article_content}
    ---

    خروجی را فقط به صورت یک آرایه JSON از اشیاء برگردان. هر شیء باید کلیدهای "tag" (رشته)، "relevance" (یکی از سه سطح ارتباطی) و "score" (عدد) را داشته باشد.
    """

    payload = {
        "contents": [{"parts": [{"text": user_prompt}]}],
        "systemInstruction": {"parts": [{"text": system_instruction}]},
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.2,
            "response_schema": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "tag": {"type": "string"},
                        "relevance": {"type": "string"},
                        "score": {"type": "number"}
                    },
                    "required": ["tag", "relevance", "score"]
                }
            }
        }
    }

    try:
        response = requests.post(f"{url}?key={api_key}", json=payload, headers=headers)
        response.raise_for_status()
        json_text = response.json().get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "[]")
        return json.loads(json_text)
    except Exception as e:
        st.error(f"خطا در دریافت پیشنهادات: {str(e)}")
        return []

def cluster_tags_from_api(all_tags, api_key):
    if not api_key:
        raise ValueError("کلید API یافت نشد. لطفاً آن را وارد کنید.")
    
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    headers = {"Content-Type": "application/json"}
    system_instruction = """
    شما یک کتابدار و متخصص طبقه‌بندی اطلاعات هستید. وظیفه شما این است که یک لیست از تگ‌ها را دریافت کرده و آن‌ها را بر اساس موضوع و مفهوم در دسته‌های منطقی گروه‌بندی کنید. نام دسته‌ها باید توسط خود شما و بر اساس محتوای تگ‌ها ابداع شود.
    """
    user_prompt = f"""
    وظیفه:
    لیست تگ‌های زیر را تحلیل کرده و آن‌ها را در دسته‌های موضوعی مرتبط گروه‌بندی کن.

    قوانین:
    1. **ایجاد دسته‌ها:** نام دسته‌ها باید کوتاه، واضح و به زبان فارسی باشد.
    2. **استفاده از تگ‌ها:** تمام تگ‌های موجود در لیست باید فقط در یک دسته قرار گیرند.
    3. **دقت:** دسته‌بندی باید بر اساس ارتباط معنایی قوی بین تگ‌ها باشد.
    4. **خروجی JSON:** نتیجه را به صورت یک آرایه JSON از اشیاء برگردان. هر شیء باید شامل دو کلید باشد: "category" (نام دسته‌ای که ایجاد کردی) و "tags" (آرایه‌ای از تگ‌های متعلق به آن دسته).

    لیست تگ‌ها برای دسته‌بندی:
    ---
    {all_tags}
    ---
    """

    payload = {
        "contents": [{"parts": [{"text": user_prompt}]}],
        "systemInstruction": {"parts": [{"text": system_instruction}]},
        "generationConfig": {
            "response_mime_type": "application/json",
            "temperature": 0.1,
            "response_schema": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "category": {"type": "string"},
                        "tags": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["category", "tags"]
                }
            }
        }
    }

    try:
        response = requests.post(f"{url}?key={api_key}", json=payload, headers=headers)
        response.raise_for_status()
        json_text = response.json().get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "[]")
        return json.loads(json_text)
    except Exception as e:
        st.error(f"خطا در دسته‌بندی تگ‌ها: {str(e)}")
        return []

# مدیریت حالت‌ها با Session State
if "api_key" not in st.session_state:
    st.session_state.api_key = ""
if "all_tags" not in st.session_state:
    st.session_state.all_tags = "تکنولوژی, هوش مصنوعی, برنامه نویسی, وب, موبایل, امنیت, گجت, نرم افزار, سخت افزار, بازی, اینترنت اشیا, داده کاوی, علی بن ابی‌طالب, تاریخ اسلام, شخصیت‌های مذهبی, نهج البلاغه, فال حافظ, شعر فارسی, ادبیات کلاسیک, عرفان"
if "article_content" not in st.session_state:
    st.session_state.article_content = ""
if "suggested_tags" not in st.session_state:
    st.session_state.suggested_tags = []
if "selected_tags" not in st.session_state:
    st.session_state.selected_tags = {}
if "clustered_tags" not in st.session_state:
    st.session_state.clustered_tags = []
if "search_query" not in st.session_state:
    st.session_state.search_query = ""
if "is_tag_list_locked" not in st.session_state:
    st.session_state.is_tag_list_locked = True

# هدر اصلی با طراحی جدید
st.markdown("""
    <div class="main-header">
        <h1 style="margin:0; font-size: 2.5rem;">🏷️ پیشنهاد دهنده هوشمند تگ</h1>
        <p style="margin:10px 0 0 0; font-size: 1.2rem; opacity: 0.9;">
        تگ‌های مناسب برای مقالات خود را به کمک هوش مصنوعی پیدا کنید
        </p>
    </div>
""", unsafe_allow_html=True)

# استفاده از تب‌ها برای سازماندهی بهتر
tab1, tab2, tab3 = st.tabs(["🎯 پیشنهاد تگ", "📚 مدیریت تگ‌ها", "⚙️ تنظیمات"])

with tab1:
    st.markdown('<div class="custom-card">', unsafe_allow_html=True)
    st.subheader("📝 محتوای مقاله")
    
    st.session_state.article_content = st.text_area(
        "متن یا عنوان مقاله خود را وارد کنید:",
        placeholder="""مثال: 
مقاله‌ای در مورد تاثیر هوش مصنوعی بر توسعه نرم‌افزارهای مدرن و تغییر روش‌های برنامه‌نویسی...
        """,
        value=st.session_state.article_content,
        height=150,
        label_visibility="collapsed"
    )
    st.markdown('</div>', unsafe_allow_html=True)

    # دکمه پیشنهاد تگ‌ها
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        if st.button(
            "🚀 دریافت تگ‌های پیشنهادی", 
            use_container_width=True,
            disabled=not (st.session_state.article_content.strip() and st.session_state.all_tags.strip()),
            type="primary"
        ):
            if not st.session_state.api_key:
                st.error("❌ لطفاً ابتدا کلید API را در تب تنظیمات وارد کنید.")
            else:
                with st.spinner("🤖 در حال تحلیل محتوا و پیشنهاد تگ‌های مرتبط..."):
                    suggested_tags = suggest_tags_from_api(
                        st.session_state.article_content,
                        st.session_state.all_tags,
                        st.session_state.api_key
                    )
                    st.session_state.suggested_tags = suggested_tags
                    st.session_state.selected_tags = {tag["tag"]: True for tag in suggested_tags}
                    st.rerun()

    # نمایش تگ‌های پیشنهادی
    if st.session_state.suggested_tags:
        st.markdown('<div class="custom-card">', unsafe_allow_html=True)
        st.subheader("🎯 تگ‌های پیشنهادی")
        
        st.write("**لیست تگ‌های پیشنهادی:**")
        
        # نمایش تگ‌ها
        for i, tag in enumerate(sorted(st.session_state.suggested_tags, key=lambda x: x["score"], reverse=True)):
            col1, col2, col3 = st.columns([3, 2, 2])
            with col1:
                # نمایش تگ با رنگ‌بندی بر اساس سطح ارتباط
                relevance_class = ""
                if tag["relevance"] == "ارتباط اصلی":
                    relevance_class = "primary"
                elif tag["relevance"] == "ارتباط ثانویه":
                    relevance_class = "secondary"
                
                st.markdown(f'<span class="tag-chip {relevance_class}">{tag["tag"]}</span>', unsafe_allow_html=True)
            with col2:
                st.write(tag["relevance"])
            with col3:
                # نمایش امتیاز با progress bar
                score = tag["score"]
                st.progress(score/100, text=f"{score}%")
        
        # کپی تگ‌ها - نسخه اصلاح شده
        selected_tags_list = [tag["tag"] for tag in st.session_state.suggested_tags]
        if selected_tags_list:
            tags_to_copy = ", ".join(selected_tags_list)
            st.write("**تگ‌های پیشنهادی:**")
            col1, col2 = st.columns([3, 1])
            with col1:
                # ایجاد یک text area برای کپی راحت‌تر
                copied_text = st.text_area(
                    "تگ‌ها برای کپی:",
                    value=tags_to_copy,
                    height=60,
                    key="tags_copy_area"
                )
            with col2:
                if st.button("📋 کپی", use_container_width=True, key="copy_btn"):
                    # استفاده از JavaScript برای کپی کردن
                    js_code = f"""
                    <script>
                    function copyToClipboard() {{
                        const textArea = document.querySelector('[data-testid="stTextArea"] textarea');
                        textArea.select();
                        document.execCommand('copy');
                        alert('تگ‌ها با موفقیت کپی شدند!');
                    }}
                    copyToClipboard();
                    </script>
                    """
                    st.components.v1.html(js_code, height=0)
                    st.success("✅ تگ‌ها کپی شدند!")
        
        st.markdown('</div>', unsafe_allow_html=True)

with tab2:
    st.markdown('<div class="custom-card">', unsafe_allow_html=True)
    st.subheader("📚 مدیریت تگ‌ها")
    
    col1, col2 = st.columns([3, 1])
    with col1:
        st.write("**لیست تگ‌های مجاز:**")
        st.write("تگ‌ها را با کاما (,) جدا کنید.")
    with col2:
        lock_icon = "🔒" if st.session_state.is_tag_list_locked else "🔓"
        if st.button(lock_icon, key="lock_btn"):
            st.session_state.is_tag_list_locked = not st.session_state.is_tag_list_locked
            st.rerun()
    
    all_tags_input = st.text_area(
        "لیست تگ‌ها",
        value=st.session_state.all_tags,
        disabled=st.session_state.is_tag_list_locked,
        height=120,
        placeholder="مثال: تکنولوژی, هوش مصنوعی, برنامه نویسی, وب, موبایل...",
        label_visibility="collapsed",
        key="all_tags_input"
    )
    
    if not st.session_state.is_tag_list_locked and all_tags_input != st.session_state.all_tags:
        st.session_state.all_tags = all_tags_input
        # ریست کردن دسته‌بندی وقتی تگ‌ها تغییر می‌کنند
        st.session_state.clustered_tags = []
    
    if st.button("🔄 به‌روزرسانی دسته‌بندی", use_container_width=True, key="update_clusters"):
        if st.session_state.api_key and st.session_state.all_tags.strip():
            with st.spinner("در حال دسته‌بندی تگ‌ها..."):
                st.session_state.clustered_tags = cluster_tags_from_api(st.session_state.all_tags, st.session_state.api_key)
            st.rerun()
        else:
            st.error("لطفاً ابتدا کلید API را وارد کنید و لیست تگ‌ها را پر کنید.")
    
    st.markdown('</div>', unsafe_allow_html=True)

    # مرورگر تگ‌ها
    st.markdown('<div class="custom-card">', unsafe_allow_html=True)
    st.subheader("🔍 مرورگر تگ‌ها")
    
    # استفاده از on_change برای مدیریت state
    def update_search_query():
        st.session_state.search_query = st.session_state.search_input
    
    search_input = st.text_input(
        "جستجو بین تگ‌ها...",
        value=st.session_state.search_query,
        placeholder="نام تگ را جستجو کنید...",
        key="search_input",
        on_change=update_search_query
    )
    
    # دسته‌بندی تگ‌ها
    if not st.session_state.clustered_tags and st.session_state.api_key and st.session_state.all_tags.strip():
        with st.spinner("در حال دسته‌بندی تگ‌ها..."):
            st.session_state.clustered_tags = cluster_tags_from_api(st.session_state.all_tags, st.session_state.api_key)
        st.rerun()
    
    if st.session_state.clustered_tags:
        filtered_groups = []
        for group in st.session_state.clustered_tags:
            filtered_tags = [tag for tag in group["tags"] if st.session_state.search_query.lower() in tag.lower()] if st.session_state.search_query else group["tags"]
            if filtered_tags:
                filtered_groups.append({"category": group["category"], "tags": filtered_tags})
        
        if filtered_groups:
            for group in filtered_groups:
                st.write(f"**{group['category']}**")
                tags_html = "".join([f'<span class="tag-chip">{tag}</span>' for tag in group["tags"]])
                st.markdown(tags_html, unsafe_allow_html=True)
                st.write("")
        else:
            st.info("🔍 هیچ تگی با این مشخصات یافت نشد.")
    else:
        st.info("📝 برای مشاهده دسته‌بندی تگ‌ها، دکمه 'به‌روزرسانی دسته‌بندی' را بزنید.")
    
    st.markdown('</div>', unsafe_allow_html=True)

with tab3:
    st.markdown('<div class="custom-card">', unsafe_allow_html=True)
    st.subheader("⚙️ تنظیمات API")
    
    st.info("""
    **برای استفاده از این ابزار، شما نیاز به کلید Gemini API دارید:**
    1. به [Google AI Studio](https://ai.google.dev/) مراجعه کنید
    2. وارد حساب Google خود شوید
    3. API Key جدید ایجاد کنید
    4. کلید را در فیلد زیر وارد نمایید
    """)
    
    api_key_input = st.text_input(
        "کلید Gemini API",
        type="password",
        value=st.session_state.api_key,
        placeholder="کلید API خود را اینجا وارد کنید...",
        key="api_key_input"
    )
    
    if st.button("💾 ذخیره کلید API", use_container_width=True, key="save_api"):
        st.session_state.api_key = api_key_input.strip()
        if st.session_state.api_key:
            st.success("✅ کلید API با موفقیت ذخیره شد!")
        else:
            st.warning("⚠️ کلید API پاک شد.")
        st.rerun()
    
    if st.session_state.api_key:
        st.success("✅ کلید API تنظیم شده است")
    else:
        st.error("❌ کلید API تنظیم نشده است")
    
    st.markdown('</div>', unsafe_allow_html=True)

# پاورقی
st.markdown("---")
st.markdown(
    "<p style='text-align: center; color: #666;'>طراحی شده برای بهبود فرآیند تولید محتوا • از قدرت هوش مصنوعی استفاده کنید</p>",
    unsafe_allow_html=True
)
