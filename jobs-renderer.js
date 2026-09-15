function normalizeJob(job, fallbackCategory, fallbackLabel) {
    const title = job && job.title ? job.title : 'Untitled Position';
    return {
        title: title,
        company: job && job.company ? job.company : '',
        location: job && job.location ? job.location : '',
        employmentType: job && (job.employmentType || job.employment_type) ? (job.employmentType || job.employment_type) : '',
        tag: job && job.tag ? job.tag : (fallbackLabel || fallbackCategory || 'General'),
        url: job && job.url ? job.url : '',
        description: job && job.description ? job.description : ''
    };
}

function getRenderableJobCategories() {
    const groups = Array.isArray(window.jobCategories) ? window.jobCategories : [];
    const merged = {};

    groups.forEach(function(group) {
        if (!group || !group.category) return;
        const category = String(group.category);
        const label = group.label || category;
        if (!merged[category]) {
            merged[category] = { category: category, label: label, jobs: [] };
        }

        const jobs = Array.isArray(group.jobs) ? group.jobs : [];
        jobs.forEach(function(job) {
            const normalized = normalizeJob(job, category, label);
            const key = [normalized.title, normalized.company, normalized.url].join('|').toLowerCase();
            const existing = merged[category].jobs.some(function(existingJob) {
                const existingKey = [existingJob.title, existingJob.company, existingJob.url].join('|').toLowerCase();
                return existingKey === key;
            });

            if (!existing) {
                merged[category].jobs.push(normalized);
            }
        });
    });

    return Object.keys(merged).map(function(category) {
        return merged[category];
    });
}

function renderJobs() {
    let container = document.getElementById('jobContainer');
    if (!container) return;
    container.innerHTML = '';

    const categories = typeof getRenderableJobCategories === 'function'
        ? getRenderableJobCategories()
        : (Array.isArray(window.jobCategories) ? window.jobCategories : []);
    if (!categories.length) return;

    function safeText(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#039;');
    }

    categories.forEach(function(categoryGroup) {
        let block = document.createElement('div');
        block.className = 'category-block';
        block.dataset.categoryGroup = categoryGroup.category;

        let heading = document.createElement('h3');
        heading.className = 'category-heading';
        heading.textContent = categoryGroup.label;
        block.appendChild(heading);

        categoryGroup.jobs.forEach(function(job) {
            let card = document.createElement('div');
            card.className = 'job-card';
            card.dataset.category = categoryGroup.category;
            card.tabIndex = 0;
            if (job.url) card.dataset.url = job.url;

            let description = job.description || ('This ' + (job.tag || categoryGroup.label) + ' opportunity at ' + job.company + ' is a strong fit for students and alumni seeking practical experience, career growth, and role-based development in ' + (categoryGroup.label || 'this field') + '.');

            card.innerHTML =
                '<h3>' + safeText(job.title) + '</h3>' +
                '<p class="company">' + safeText(job.company) + '</p>' +
                '<p class="job-info">' + safeText(job.location) + '</p>' +
                '<p class="job-info">' + safeText(job.employmentType) + '</p>' +
                '<span class="job-tag">' + safeText(job.tag) + '</span>' +
                '<div class="job-description">' + safeText(description) + '</div>' +
                '<button class="apply-btn" type="button">Apply Now</button>';

            card.querySelector('.apply-btn').addEventListener('click', function(event) {
                event.stopPropagation();
                applyJob(job.title, job.url);
            });

            card.addEventListener('click', function(event) {
                if (event.target && event.target.closest('.apply-btn')) {
                    return;
                }
                card.classList.toggle('is-open');
            });

            card.addEventListener('keydown', function(event) {
                if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    card.classList.toggle('is-open');
                }
            });

            block.appendChild(card);
        });

        if (categoryGroup.category === 'Education') {
            let linkPanel = document.createElement('div');
            linkPanel.className = 'course-link-panel';
            linkPanel.innerHTML =
                '<p>More Education job resources:</p>' +
                '<ul>' +
                '<li><a href="https://ph.jobstreet.com/teaching-jobs/in-Iligan-City-Lanao-del-Norte" target="_blank" rel="noopener noreferrer">JobStreet: Teaching Jobs in Iligan City</a></li>' +
                '<li><a href="https://ph.jobsora.com/jobs-teacher-iligan-city" target="_blank" rel="noopener noreferrer">Jobsora: Teacher Jobs in Iligan City</a></li>' +
                '<li><a href="https://ph.indeed.com/q-teacher-hiring,-iligan-city-l-iligan-jobs.html?vjk=2c527dc98bc55bdf" target="_blank" rel="noopener noreferrer">Indeed: Teacher Hiring in Iligan City</a></li>' +
                '<li><a href="https://www.indeed.com/q-school-teacher-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: School Teacher Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/education-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Education Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/teaching-jobs-SRCH_KO0,13.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Teaching & Education Jobs</a></li>' +
                '<li><a href="https://sites.google.com/deped.gov.ph/depedign-t1application/home?fbclid=IwY2xjawTeesdwZWVtAjEwAGJyaWQRMWgyRGVGQU83YUZkWVFsZG1zcnRjBmFwcF9pZBAyMjIwMzkxNzg4MjAwODkyAAEebs609GU05MsPFVfxYekpyiEysWamRGy287LTgjM3uI8HKKZ4LqMSHEHpngU_aem_2OSJ-w4d6Vf5v5aBQ_O70Q" target="_blank" rel="noopener noreferrer">DepEd: Teacher Application Portal</a></li>' +
                '<li><a href="https://main.depedldn.com/vacant-positions/" target="_blank" rel="noopener noreferrer">DepEd LDN: Vacant Positions</a></li>' +
                '</ul>';
            block.appendChild(linkPanel);
        }

        if (categoryGroup.category === 'Business') {
            let businessLinkPanel = document.createElement('div');
            businessLinkPanel.className = 'course-link-panel';
            businessLinkPanel.innerHTML =
                '<p>More Business job resources:</p>' +
                '<ul>' +
                '<li><a href="https://ph.indeed.com/q-companies-in-iligan-hiring-l-iligan-jobs.html?vjk=72a9f1b9d79fe4c3" target="_blank" rel="noopener noreferrer">Indeed: Companies Hiring in Iligan</a></li>' +
                '<li><a href="https://ph.jobstreet.com/business+management-jobs/in-Iligan-City-Lanao-del-Norte" target="_blank" rel="noopener noreferrer">JobStreet: Business & Management Jobs in Iligan City</a></li>' +
                '<li><a href="http://glassdoor.com/Job/iligan-fresh-graduate-jobs-SRCH_IL.0,6_IC2297214_KO7,21.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Iligan Fresh Graduate Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/finance-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Finance Jobs</a></li>' +
                '<li><a href="https://www.indeed.com/q-business-administrator-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Business Administrator Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/business-jobs-SRCH_KO0,8.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Business & Office Jobs</a></li>' +
                '</ul>';
            block.appendChild(businessLinkPanel);
        }

        if (categoryGroup.category === 'Healthcare') {
            let healthcareLinkPanel = document.createElement('div');
            healthcareLinkPanel.className = 'course-link-panel';
            healthcareLinkPanel.innerHTML =
                '<p>More Healthcare job resources:</p>' +
                '<ul>' +
                '<li><a href="https://ph.jobstreet.com/healthcare-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Healthcare Jobs</a></li>' +
                '<li><a href="https://ph.jobsora.com/jobs-nursing-assistant-iligan-city" target="_blank" rel="noopener noreferrer">Jobsora: Nursing Assistant Jobs in Iligan City</a></li>' +
                '<li><a href="https://ph.indeed.com/q-department-of-health,-medical-technologist-l-iligan-jobs.html?vjk=19a6e9c341129f8f" target="_blank" rel="noopener noreferrer">Indeed: Department of Health Medical Technologist Jobs in Iligan</a></li>' +
                '<li><a href="https://www.indeed.com/q-nursing-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Nursing Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/medical-technologist-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Medical Technologist Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/healthcare-jobs-SRCH_KO0,11.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Healthcare Jobs</a></li>' +
                '</ul>';
            block.appendChild(healthcareLinkPanel);
        }

        if (categoryGroup.category === 'CCJE') {
            let ccjeLinkPanel = document.createElement('div');
            ccjeLinkPanel.className = 'course-link-panel';
            ccjeLinkPanel.innerHTML =
                '<p>More CCJE job resources:</p>' +
                '<ul>' +
                '<li><a href="https://www.pnp.gov.ph/" target="_blank" rel="noopener noreferrer">PNP: Philippine National Police</a></li>' +
                '<li><a href="https://sc.judiciary.gov.ph/" target="_blank" rel="noopener noreferrer">Supreme Court of the Philippines</a></li>' +
                '<li><a href="https://ph.jobstreet.com/criminology-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Criminology Jobs</a></li>' +
                '<li><a href="https://www.indeed.com/q-criminology-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Criminology Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/criminal-justice-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Criminal Justice Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/criminal-justice-jobs-SRCH_KO0,16.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Criminal Justice Jobs</a></li>' +
                '</ul>';
            block.appendChild(ccjeLinkPanel);
        }

        if (categoryGroup.category === 'Social Work') {
            let socialWorkLinkPanel = document.createElement('div');
            socialWorkLinkPanel.className = 'course-link-panel';
            socialWorkLinkPanel.innerHTML =
                '<p>More Social Work job resources:</p>' +
                '<ul>' +
                '<li><a href="https://ph.jobstreet.com/social-work-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Social Work Jobs</a></li>' +
                '<li><a href="https://www.indeed.com/q-social-worker-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Social Worker Openings</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/social-work-jobs-SRCH_KO0,11.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Social Work Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/community-development-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Community Development Jobs</a></li>' +
                '<li><a href="https://ph.indeed.com/q-social-work-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Social Work Jobs (Philippines)</a></li>' +
                '</ul>';
            block.appendChild(socialWorkLinkPanel);
        }

        if (categoryGroup.category === 'CHTM') {
            let chtmLinkPanel = document.createElement('div');
            chtmLinkPanel.className = 'course-link-panel';
            chtmLinkPanel.innerHTML =
                '<p>More CHTM job resources:</p>' +
                '<ul>' +
                '<li><a href="https://ph.jobstreet.com/hospitality-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Hospitality Jobs</a></li>' +
                '<li><a href="https://www.indeed.com/q-hospitality-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Hospitality & Tourism Jobs</a></li>' +
                '<li><a href="https://www.tourism.gov.ph/careers" target="_blank" rel="noopener noreferrer">DOT: Tourism Careers Philippines</a></li>' +
                '<li><a href="https://ph.jobstreet.com/hotel-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Hotel Jobs</a></li>' +
                '<li><a href="https://www.indeed.com/q-tourism-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Tourism Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/hospitality-jobs-SRCH_KO0,12.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Hospitality Jobs</a></li>' +
                '</ul>';
            block.appendChild(chtmLinkPanel);
        }

        if (categoryGroup.category === 'IT') {
            let itLinkPanel = document.createElement('div');
            itLinkPanel.className = 'course-link-panel';
            itLinkPanel.innerHTML =
                '<p>More IT job resources:</p>' +
                '<ul>' +
                '<li><a href="https://www.glassdoor.com/Job/iligan-city-it-jobs-SRCH_IL.0,11_IC4770610_KO12,14.htm" target="_blank" rel="noopener noreferrer">Glassdoor: Iligan City IT Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/it-related-jobs/in-Iligan-City-Lanao-del-Norte" target="_blank" rel="noopener noreferrer">JobStreet: IT-related Jobs in Iligan City</a></li>' +
                '<li><a href="https://ph.indeed.com/q-it-l-northern-mindanao-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: IT Jobs in Northern Mindanao</a></li>' +
                '<li><a href="https://www.indeed.com/q-software-developer-jobs.html" target="_blank" rel="noopener noreferrer">Indeed: Software Developer Jobs</a></li>' +
                '<li><a href="https://ph.jobstreet.com/software-engineer-jobs" target="_blank" rel="noopener noreferrer">JobStreet: Software Engineer Jobs</a></li>' +
                '<li><a href="https://www.glassdoor.com/Job/it-jobs-SRCH_KO0,2.htm" target="_blank" rel="noopener noreferrer">Glassdoor: IT & Software Jobs</a></li>' +
                '</ul>';
            block.appendChild(itLinkPanel);
        }

        container.appendChild(block);
    });
}

window.addEventListener('DOMContentLoaded', function() {
    renderJobs();
});
