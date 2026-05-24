---
title: My Projects
layout: page
order: 6
icon: fas fa-code
excerpt_separator: ""
---

{% for project in site.data.projects %}

## {{ project.title }}

**Description**  
{{ project.long_description }}

**Stack**  
{% for tech in project.stack %}`{{ tech }}`{% unless forloop.last %} · {% endunless %}{% endfor %}

**Key Features**  
{% for feature in project.features %}
- {{ feature }}
{% endfor %}

**Source Code**  
[{{ project.repository_url | remove: "https://" }}]({{ project.repository_url }})

{% if project.screenshot %}

![{{ project.title }}]({{ project.screenshot }}){: .w-60 .mx-auto .d-block .rounded-10 .shadow }

{% endif %}

---

{% endfor %}
