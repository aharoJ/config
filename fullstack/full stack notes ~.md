Full Stack Journey 

---
---
# Chapter 1
# The process framework / flow `*`[10]
## what is the process framework?
- A process framework establishes the foundation for a complete software engineering process by identifying a small number of framework activities that are applicable to all software projects, regardless of their size or complexity. In addition, the process framework encompasses a set of umbrella activities that are applicable across the entire software process. A generic process framework for software engineering encompasses five activities:
- These five generic framework activities can be used during the development of small, simple programs; the creation of Web applications; and for the engineering of large, complex computer-based systems. The details of the software process will be quite different in each case, but the framework activities remain the same.
- For many software projects, framework activities are applied iteratively as a project progresses. That is, communication, planning, modeling, construction, and deployment are applied repeatedly through a number of project iterations. Each iteration produces a software increment that provides stakeholders with a subset of overall software features and functionality. As each increment is produced, the software becomes more and more complete.

### divided in 5 pieces []
## communication
Before any technical work can commence, it is critically important
to communicate and collaborate with the customer (and other stakeholders).8 The
intent is to understand stakeholders’ objectives for the project and to gather requirements
that help define software features and functions.

## planning
Any complicated journey can be simplified if a map exists. A software
project is a complicated journey, and the planning activity creates a “map” that helps
guide the team as it makes the journey. The map—called a software project plan—
defines the software engineering work by describing the technical tasks to be conducted,
the risks that are likely, the resources that will be required, the work products
to be produced, and a work schedule

## modeling 
Whether you’re a landscaper, a bridge builder, an aeronautical engineer,
a carpenter, or an architect, you work with models every day. You create a “sketch”
of the thing so that you’ll understand the big picture—what it will look like architecturally,
how the constituent parts fit together, and many other characteristics. If
required, you refine the sketch into greater and greater detail in an effort to better
understand the problem and how you’re going to solve it. A software engineer does
the same thing by creating models to better understand software requirements and the
design that will achieve those requirements.
## construction 
What you design must be built. This activity combines code generation
(either manual or automated) and the testing that is required to uncover errors in
the code.

## deployment 
The software (as a complete entity or as a partially completed increment)
is delivered to the customer who evaluates the delivered product and provides
feedback based on the evaluation.

---
---

# Umbrella Activity  [11]
Software engineering process framework activities are complemented by a number of umbrella activities. In general, umbrella activities are applied throughout a software project and help a software team manage and control progress, quality, change, and risk. Typical umbrella activities include:

## Umbrella Activities
- Software project tracking and control
- Risk management
- Software quality assurance
- Technical reviews
- Measurement
- Software configuration management
- Reusability management
- Work product preparation and production


## What is Umbrella for?
- team manage
- control progress
- quality
- change 
- risk

---
---


# Software Application Domains  [7]

Software can be:
	product or providing software

software is:
	logical (set of instructions)

## System software
## Application software
## Engineering/scientific software
## Embedded software
## Product-line software
## Web/mobile applications
## Artificial intelligence software


---
---


# .
# .
# .
# Chapter 2
---
---
# Comparing Process Models [pros - cons]
## Spiral Process Model  [34]
### Spiral Pros
- Continuous customer involvement.
- Development risks are managed.
- Suitable for large, complex projects.
- It works well for extensible products.
### Spiral Cons
- Risk analysis failures can doom the project.
- Project may be hard to manage.
- Requires an expert development team.

Spiral Principle 
--> ??????

## Prototyping Process Model  [34]
### Prototyping pros 
- There is a reduced impact of requirement changes.
- The customer is involved early and often.
- It works well for small projects.
- There is reduced likelihood of product rejection.

### Prototyping cons
- Customer involvement may cause delays.
- There may be a temptation to “ship” a prototype.
- Work is lost in a throwaway prototype.
- It is hard to plan and manage.


---
---


# Prescriptive Process Models [25]
## Process elements
- framework activities
- software engineering actions
- tasks
- work products
- quality assurance
- change control mechanisms 
[6 bullet points]





### Asynchronous to Process Framework
**Prescriptive process models** strive for structure and order in software development. Activities and tasks occur sequentially with defined guidelines for progress. We call them “prescriptive” because they prescribe a set of process elements— framework activities, software engineering actions, tasks, work products, quality assurance, and change control mechanisms for each project.


---
---


# All Phases
## inception phase
is where customer communication and planning takes place.
--> basic idea
## elaboration phase
The planning and modeling activities of the generic process model.
--> evolution 
-->  Developing a **refined** requirements
## elicitation phase
-->  end goal (:
-->  understanding the goals 



## Negotiation Phase 
-->  rank (priority) requirements 
## construction phase
Is identical to the construction activity defined for the generic software process. 
## transition phase
Encompasses the latter stages of the generic construction activity and the first part of the generic deployment (delivery and feedback) activity.
## production phase
Coincides with the deployment activity of the generic process.



stakeholders:
--> anyone who benefits in a **direct or indirect** way from  the system which is being developed.

non-functional-requirement:
--> quality
--> security
--> performance 
--> end user does understand this stuff **but we** do


---
---


# .
# .
# .
# Chapter 3


# Agility Principles  [40, 41] `*`
## what are the principles of agility? 
-  Customer satisfaction is achieved by providing value through software that is delivered to the customer as rapidly as possible.
-  Develop recognize that requirements will change and welcome changes.
-  Deliver software increments frequently (weeks not months) to stakeholders to ensure feedback on their deliveries is meaningful.
-  Agile team populated by motivated individuals using face-to-face communication to convey information.
-  Team process encourages technical excellence, good design, simplicity, and avoids unnecessary work.
-  Working software that meets customer needs is the primary goal.
-  Pace and direction of the team’s work must be “sustainable,” enabling them to work effectively for long periods of time.
-  An agile team is a “self-organizing team”—one that can be trusted develop well-structured architectures that lead to solid designs and customer satisfaction.
-  Part of the team culture is to consider its work introspectively with the intent of improving how to become more effective its primary goal (customer satisfaction).


---
---

# Scrum [42]
## scrum framework activities  
- requirements
- analysis 
- design
- evolution
- delivery

## scrum principles -agile-
- Scrum principles are consistent with the agile manifesto and are used to guide development activities within a process that incorporates the following framework activities: requirements, analysis, design, evolution, and delivery.
- These principles include empiricism, self-organization, collaboration, value-based prioritization, time-boxing, iterative development, and continuous improvement.

## purpose of daily scrum meeting
- Talk about your daily work for 15 min
- What is the daily plan or talk about the plan for 24 hours

## what is a scrum backlog? 
- A Scrum Backlog is a prioritized list of product features or requirements that the team works on during a Sprint. The Backlog is managed by the Product Owner, who is responsible for defining and prioritizing the work based on the needs of the business and the customers.

#### summary
sprint planning:
	order of importance 

sprint backlog:
	do one of the task 

#### Backlog Refinement Meeting:
- Developers work with stakeholders to create product backlog.
#### Sprint Planning Meeting:
- Backlog partitioned into “sprints” derived from backlog and next sprint defined.
#### Daily Scrum Meeting:
- Team members synchronize their activities and plan work day (15 minutes max).
#### Sprint Review:
- Prototype “demos” are delivered to the stakeholders for approval or rejection.
#### Sprint Retrospective:
- After sprint is complete, team considers what went well and what needs improvement.

Pros
•Product owner sets priorities.
•Team owns decision making.
•Documentation is lightweight.
•Supports frequent updating.

Cons
•Difficult to control the cost of changes.
•May not be suitable for large teams.
•Requires expert team members.


---
---

# Agile
## What is an Agile team? 
- An Agile team is a group of individuals who work together to deliver software using Agile methodology. An Agile team is typically cross-functional, meaning that it includes individuals with different skills and expertise, such as developers, testers, designers, and analysts. The team works collaboratively, using an iterative and incremental approach to software development, with a focus on delivering value to the customer.

## What is expected from an Agile team?
- An Agile team is expected to be self-organizing, cross-functional, and collaborative. The team should work together to plan and execute their work, using an iterative and incremental approach to software development. The team is also expected to prioritize customer satisfaction, deliver working software frequently, respond quickly to changes in requirements, and continuously improve their processes. 
### Other expectations of an Agile team include:
-   Open communication and transparency
-   Willingness to embrace change and adapt to new requirements
-   Focus on delivering value to the customer
-   Dedication to continuous improvement and learning
-   Commitment to working together as a team to achieve shared goals
-   Emphasis on quality and the use of best practices and standards
-   Responsibility for delivering a high-quality product that meets the needs of the business and the customer.


---
---


# Sprint  [45]
## What is Sprint?
- A Sprint is a time-boxed iteration of development work in the Scrum framework. It is a short period of time, typically between one and four weeks, during which the team works to deliver a potentially releasable product increment.
## Sprint Review Meeting 
how long is it?
	4 weeks
	4 hours 
### Overview
- 
- The sprint review occurs at the end of the sprint when the development team has judged the increment complete. The sprint review is often time-boxed as a 4-hour meeting for a 4-week sprint. The Scrum master, the development team, the product owner, and selected stakeholders attend this review. The primary activity is a demo of the software increment completed during the sprint. It is important to note that the demo may not contain all planned functionality, but rather those functions that were to be delivered within the time-box defined for the sprint. 
- 
- The product owner may accept the increment as complete or not. If it is not accepted, the product owner and the stakeholders provide feedback to allow a new round of sprint planning to take place. This is the time when new features may be added or removed from the product backlog. The new features may affect the nature of the increment developed in the next sprint.


---
---


# The Extreme Programming process (XP) [47]
## XP Planning 
- Begins with user stories, team estimates cost, stories grouped into increments, commitment made on delivery date, computer project velocity.

## XP Design
- Follows KIS principle, encourages use of CRC cards, design prototypes, and refactoring.

## XP Coding
- construct unit tests before coding, uses pair.

## XP Testing 
- unit tests executed daily, acceptance tests define by customer.

--> PAIR PORGAMMING

Pros
•Emphasizes customer involvement.
•Establishes rational plans and schedules.
•High developer commitment to the project.
•Reduced likelihood of product rejection.


Cons
•Temptation to “ship” a prototype.
•Requires frequent meetings about increasing costs.
•Allows for excessive changes.
•Depends on highly skilled team members.


---
---


# Kanban Details [50]
--> VISUALIZATION 

•Visualizing workflow using a Kanban board.
•Limiting the amount of work in progress at any given time.
•Managing workflow to reduce waste by understanding the current value flow.
•Making process policies explicit and the criteria used to define “done”.
•Focusing on continuous improvement by creating feedback loops where changes are introduced.
•Make process changes collaboratively and involve all stakeholders as needed.

Pros
•Lower budget and time requirements.
•Allows early product delivery.
•Process policies written down.
•Continuous process improvement.

Cons
•Team collaboration skills determine success.
•Poor business analysis can doom the project.
•Flexibility can cause developers to lose focus.
•Developer reluctance to use measurement.


---
---


# .
# .
# .
# Chapter 4

---
---

# Professor mentioned but not sure where it goes
## Requirement Definition
- identifying
- analyzing 
- documenting the requirements for a software project.


## Which prototype provides an interface
- In software development, a prototype is a preliminary version of a software product that is used to test and refine the design. The type of prototype that provides an interface is a user interface (UI) prototype, which is a mockup or simulation of the software's graphical user interface (GUI). A UI prototype is used to test the usability and functionality of the interface before the software is developed. The first thing that a UI prototype typically provides is a visual representation of the software's interface, including the layout, navigation, and functionality.


---
---


# No-go prototype  
- When its too much money
- too many problems / issues

first provided interface  
- In software development, a user interface (UI) prototype is a preliminary version of a software product's graphical user interface (GUI) that is used to test and refine the design. The UI prototype provides a visual representation of the software's interface, including the layout, navigation, and functionality.

supporting maintainance   
- Supporting maintenance, also known as corrective maintenance, is a type of software maintenance that involves fixing bugs or errors in the software after it has been released. This type of maintenance is focused on keeping the software running smoothly and preventing issues from affecting users. Supporting maintenance may also involve making minor updates or modifications to the software to address user feedback or changing requirements. The goal of supporting maintenance is to ensure that the software continues to meet the needs of the business and the customers over time.

### these are derived from internet not book/slides


---
---

# .
# .
# .
# Chapter 5 
# social media, toxic, sense of trust && success 
## Traits of Successful Software Engineers
- Sense of individual responsibility.
- Acutely aware of the needs of team members and stakeholders.
- Brutally honest about design flaws and offers constructive criticism.
- Resilient under pressure.
- Heightened sense of fairness.
- Attention to detail.
- Pragmatic adapting software engineering practices based on the circumstances  at hand.

## Symptoms of Team Toxicity
-  A frenzied work atmosphere where team members waste energy and lose focus on work objectives.
-  High frustration that causes friction among team members.
-  Fragmented or poorly coordinated software process model that becomes a roadblock to accomplishment.
-  Unclear definition of team roles resulting in a lack of accountability and resultant finger-pointing.
-  Continuous and repeated exposure to failure that leads to a loss of confidence and poor morale.

## Impact of Social Media
- Social processes around software development are  highly depend on engineers’ abilities to connect with individuals who share similar goals and complementary skills.
- Value of social networking tools grows as team size increases or when a team is geographically dispersed.
- Privacy and security issues should not be overlooked when using social media for software engineering work.
- Benefits of social media must be weighed against the threat of uncontrolled disclosure of proprietary information.

## global team issues
- difficulty with global team
- cultural difference affects flow of work 


---
---



# .
# .
# .
# Chapter 6
### What is the most important factor for a customer?
- The QUALITY 
- Project ON TIME
- Customer will forget Delay 
	- They will NOT forget **buggy** software 

Practice of software engineering, concept, principle, methods, and tools
On time and high Quality for any model
Customers do not forget buggy software. They will forget a delay but not buggy software
In planning we want to get a road map and follow that for the rest of the build



---
---

# Communications Principles 
## Principle # 9.  
- (a) Once you agree to something, move on; 
- (b) If you can’t agree to something, move on; 
- (c) If a feature or function is unclear and cannot be clarified at the moment, move on.
## Principle # 10.  
- Negotiation is not a contest or a game. It works best when both parties win.

### Communication effectiveness
- face to face
- video - conference
- telephone
- email
- text
- paper

---
---


# .
# .
# .
# Chapter 7
### The goal of Requirement Engineering 
- is to identify, analyze, and specify the requirements for a software system in order to ensure that it meets the needs of the business and the customers.
### Collaboration Phase
- In the Collaboration phase of requirement engineering, various stakeholders work together to identify, analyze, and specify the requirements for the software system.

# What is an actor?
-  An actor is a person, organization or system that interacts with the software system being developed.
## First Actor
-  The first actor is typically the end user or customer who will be using the software system. 
## Second Actor
- The second actor may be a system or another external entity that interacts with the software system.


---
---


# Requirements Engineering 
## Inception
- establish a basic understanding of the problem, the people who want a solution, and the nature of the solution that is desired, important to establish effective customer and developer communication.

## Elicitation
- **Understand the goals**
- elicit requirements and business goals form from all stakeholders.

## Elaboration
- focuses on developing a refined requirements model that identifies aspects of software function, behavior, and information.

## who is stakeholder?
- someone who benefits  directly or indirectly 
- benefit from the system 


---
---


# Non-functional Requirements
Non-Functional Requirement (NFR) 
- quality attribute, performance attribute, security attribute, or general system constraint.
## Two-phase process is used to determine which NFR’s are compatible:
- The first phase is to create a matrix using each NFR as a column heading and the system SE guidelines a row labels.
- The second phase is for the team to prioritize each NFR using a set of decision rules to decide which to implement by classifying each NFR and guideline pair as complementary, overlapping, conflicting, or independent.


---
---


# Elicitation Work Products
- Statement of need and feasibility.
- Bounded statement of scope for the system or product.
- List of customers, users, and other stakeholders who participated in requirements elicitation,
- Description of the system’s technical environment.
- List of requirements (preferably organized by function) and the domain constraints that apply to each.
- Set of usage scenarios (written in stakeholders’ own words) that provide insight into the use of he system or product under different operating conditions.


---
---


# .
# .
# .
# Chapter 8


---
---


# Actors and User Profiles
## Actors
- A UML actor models an entity that interacts with a system object. Actors may represent roles played by human stakeholders or external hardware as they interact with system objects by exchanging information. A single physical entity may be portrayed by several actors if the physical entity takes on several roles that are relevant to realizing different system functions.

## Profile 
- A UML profile provides a way of extending an existing model to other domains or platforms. This might allow you to revise the model of a Web-based system and model the system for various mobile platforms. Profiles might also be used to model the system from the viewpoints of different users. For example, system administrators may have a different view of the functionality of an automated teller machine than end users.

## Use Cases
- A use case is a description of how a user (or actor) interacts with a software system to achieve a specific goal. Use cases are used in software development to identify and describe the various ways that users will interact with the system, and to ensure that the system is designed to meet their needs.

---
---

# UML Sequence Diagrams
### The UML sequence diagram can be used for behavioral modeling.
- Sequence diagrams can also be used to show how events cause transitions from object to object. Once events have been identified by examining a use case, the modeler creates a sequence diagram—a representation of how events cause flow from one object to another as a function of time. The sequence diagram is a shorthand version of the use case.

![](aharo24%202023-03-16%20at%207.59.46%20PM.png)



---
---


# Monday Class session
1st actor
--> ???? ion get it 
2nd actor 
--> support the system 


NO PRINCIPLE THAT GUIDE THE PROCESS 


agile process
--> 

characteristics of SWE NO

Scrum principles Yes 









# .
# .
# .
# Getting all the Tags
stakeholders:
--> anyone who benefits in a **direct or indirect** way from  the system which is being developed.

non-functional-requirement:
--> quality
--> security
--> performance 
--> end user does understand this stuff **but we** do

(1) Inception:
	-->  basic understanding 
	-->  here we find **stakeholders**
	-->  who will use the solution
*who is behind the request for this to work?* 


(2) Elicitation:
	-->  understanding the goals 

(3) Elaboration:
	-->  Developing a **refined** requirements
	model:
		creation and refinement of user **scenarios**  
	scenarios:
		how the end user will interact with the system 
	user scenarios:
		analysis classes:
			attribute 
			services 
			relationship between classes

(4) Negotiation:
	rank (priority) requirements 


• Principle #5. Build software that exhibits effective modularity. Provides a mechanism for realizing the philosophy of Separation of concerns .

•Principle # 9.  (a) Once you agree to something, move on; (b) If you can’t agree to something, move on; (c) If a feature or function is unclear and cannot be clarified at the moment, move on.











# .
# .

# Stuff for Brain to remember
## Framework Process or Process Flow:
Communication,
Planning,
Modeling,
Construction,
Deployment

## Umbrella Activities
- Software project tracking and control
- Risk management
- Software quality assurance
- Technical reviews
- Measurement
- Software configuration management
- Reusability management
- Work product preparation and production
### What is Umbrella for?
- team manage
- control progress
- quality
- change 
- risk
---

## scrum framework activities  
- requirements
- analysis 
- design
- evolution
- delivery

## Software can be? or is? 
Software can be:
- product or providing software
software is:
- logical (set of instructions)


## Spiral Process Model  ( Pro / Cons )
### Spiral Pros
- Continuous customer involvement.
- Development risks are managed.
- Suitable for large, complex projects.
- It works well for extensible products.
### Spiral Cons
- Risk analysis failures can doom the project.
- Project may be hard to manage.
- Requires an expert development team.

Spiral Principle 
--> ??????

## Prototyping Process Model  ( Pro / Cons )
### Prototyping pros 
- There is a reduced impact of requirement changes.
- The customer is involved early and often.
- It works well for small projects.
- There is reduced likelihood of product rejection.

### Prototyping cons
- Customer involvement may cause delays.
- There may be a temptation to “ship” a prototype.
- Work is lost in a throwaway prototype.
- It is hard to plan and manage.

## Principle of agility
-   Agile development prioritizes customer satisfaction through rapid delivery of working software.
-   Requirements are expected to change and are welcome.
-   Teams are cross-functional, motivated, and communicate face-to-face.
-   Processes prioritize technical excellence, simplicity, and sustainability.
-   Working software that meets customer needs is the primary goal.
-   Teams are self-organizing and continuously improve their processes.
## what is a scrum backlog? 
- A Scrum Backlog is a prioritized list of product features or requirements that the team works on during a Sprint.

##  Scrum daily meeting
- Talk about your daily work for 15 min
- What is the daily plan or talk about the plan for 24 hours

## sprint planning:
- order of importance 
## sprint backlog:
- do one of the task 

---
## stakeholders
- anyone who benefits in a **direct or indirect** way from  the system which is being developed.

## non-functional-requirement:
- quality
- security
- performance 
- end user does understand this stuff **but we** do

## What is expected from an Agile team?
-   Customer satisfaction
-   Working software
-   Collaboration and teamwork
-   Process improvement
-   Iterative and incremental approach

## Extreme Programming process (XP)
- peer programming  

## Kanban
- visualization

## No-go prototype  
- When its too much money
- too many problems / issues

### Requirement Definition
- identifying
- analyzing 
- documenting the requirements for a software project.

### Which functional prototype should have the user interface
- First construction prototype. 

### You provide prototype what is the next step
- user feedback and then add it to your system


## social media, toxicity , sense of trust && success  
-   Toxic Atmosphere/Environment: A work atmosphere where team members waste energy and lose focus on work objectives, with high frustration that causes friction among team members.
-   Impact of Social Media: Social media can be beneficial for software development by connecting engineers with others who share similar goals and complementary skills, but privacy and security issues should not be overlooked.
-   Symptoms of Team Toxicity: High frustration, unclear roles leading to lack of accountability, repeated exposure to failure, and a lack of confidence and morale.
-   Traits of Successful Software Engineers: Sense of responsibility, awareness of team/stakeholder needs, honesty, resilience, fairness, attention to detail, and ability to adapt practices based on circumstances.
-   Global Team Issues: Difficulties can arise due to cultural differences affecting the flow of work.


## What is the definition of requirement engineer?
- defining
- analyzing 
- documenting

##  Actors
### First Actor
-  The first actor is typically the end user or customer who will be using the software system. 
### Second Actor
- actor that supports the first actor  ✅
- The second actor may be a system or another external entity that interacts with the software system.
### actor overview
- In a use case, the first actor is the primary person or device that interacts with the software. The second actor is a supporting actor that also interacts with the software.


## stakeholders:
- anyone who benefits in a **direct or indirect** way from  the system which is being developed.

## non-functional-requirement (NFR)
### NFR attributes 
- quality
- security
- performance 
- end user does understand this stuff **but we** do


## What is the UML Sequence Diagram used for?
→ The UML sequence diagram can be used for behavioral modeling.
## What is a Use Case?
→ A use case is a description of how a user (or actor) interacts with a software system to achieve a specific goal.
→ Use cases Trigger goes from one case to another







# Full Stack Recap
### Chapter 1
Process Framework / Flow:
- [ ] Communication
- [ ] planning
- [ ] models
- [ ] construction
- [ ] deployment

Prescriptive Process Models:
- [ ] framework activities
- [ ] SWE actions
- [ ] tasks
- [ ] work products
- [ ] quality assurance
- [ ] change control mechanism

Umbrella Activities:
- [ ] Software project tracking and control
- [ ] Risk management
- [ ] Software quality assurance
- [ ] Technical reviews
- [ ] Measurement
- [ ] Software configuration management
- [ ] Reusability management
- [ ] Work product preparation and production

What is Umbrella for ?
- [ ] team manage
- [ ] control progress
- [ ] quality
- [ ] change 
- [ ] risk

Scrum framework activities:
- [ ] design
- [ ] evolution
- [ ] analysis
- [ ] delivery 
- [ ] requirements 

Scrum Backlog:
- [ ] A Scrum Backlog is a prioritized list of product features or requirements that the team works on during a Sprint.

Scrum daily meeting:
- [ ] Talk about your daily work for 15 min.
- [ ] Discuss the daily plan or talk about the plan for the next 24 hours.

Sprint planning:
- [ ] Prioritize the order of importance of tasks.

Sprint backlog:
- [ ] Choose and complete one task.

Sprint Review Meeting:
- [ ] 4 weeks
- [ ] 4 hours 

Software can be:
- [ ] product or providing software
- [ ] production of software

Software is:
- [ ] logical (set of instructions)


### Chapter 2
Spiral Pros:
- [ ] Continuous customer involvement.
- [ ] Development risks are managed.
- [ ] Suitable for large, complex projects.
- [ ] It works well for extensible products.

Spiral Cons:
- [ ] Risk analysis failures can doom the project.
- [ ] Project may be hard to manage.
- [ ] Requires an expert development team.

Prototyping Pros:
- [ ] There is a reduced impact of requirement changes.
- [ ] The customer is involved early and often.
- [ ] It works well for small projects.
- [ ] There is reduced likelihood of product rejection.

Prototyping Cons:
- [ ] Customer involvement may cause delays.
- [ ] There may be a temptation to “ship” a prototype.
- [ ] Work is lost in a throwaway prototype.
- [ ] It is hard to plan and manage.

Process elements:
- [ ] framework activities
- [ ] software engineering actions
- [ ] tasks
- [ ] work products
- [ ] quality assurance
- [ ] change control mechanisms

### Chapter 3
Principle of agility:
- [ ] Agile development prioritizes customer satisfaction through rapid delivery of working software
- [ ] Requirements are expected to change and are welcome
- [ ] Teams are cross-functional, motivated, and communicate face-to-face
- [ ] Processes prioritize technical excellence, simplicity, and sustainability
- [ ] Working software that meets customer needs is the primary goal
- [ ] Teams are self-organizing and continuously improve their processes

Stakeholders:
- [ ] Anyone who benefits in a direct or indirect way from the system being developed.

Agile team expectations:
- [ ] Customer satisfaction
- [ ] Working software
- [ ] Collaboration and teamwork
- [ ] Process improvement
- [ ] Iterative and incremental approach

Extreme Programming process (XP):
- [ ] Peer programming

Kanban:
- [ ] Visualization


### Chapter 4
Requirement Definition:
- [ ] Identifying
- [ ] analyzing
- [ ] documenting  req. for software project.

No-go prototype:
- [ ] When it's too much money 
- [ ] When too many problems/issues.

Which functional prototype should have the user interface?
- [ ] First construction prototype.
- [ ] Can also be known as UI 

After Prototype whats next:
- [ ] User feedback and then add it to your system.


### chapter 5
Toxic Atmosphere/Environment: 
- [ ] A work atmosphere where team members waste energy and lose focus on work objectives, with high frustration that causes friction among team members.

Impact of Social Media: 
- [ ] Social media can be beneficial for software development by connecting engineers with others who share similar goals and complementary skills, but privacy and security issues should not be overlooked.

Symptoms of Team Toxicity: 
- [ ] High frustration, unclear roles leading to lack of accountability, repeated exposure to failure, and a lack of confidence and morale.

Traits of Successful Software Engineers: 
- [ ] Sense of responsibility, awareness of team/stakeholder needs, honesty, resilience, fairness, attention to detail, and ability to adapt practices based on circumstances.

Global Team Issues: 
- [ ] Difficulties can arise due to cultural differences affecting the flow of work.

### Chapter 6
Practices of a [swe]
- [ ] software engineering
- [ ] concept 
- [ ] principle
- [ ] methods 
- [ ] tools

Customer does NOT forget:
- [ ] buggy software

Customers forget:
- [ ] a delay

### Chapter 7
First Actor:
- [ ] The first actor is typically the end user or customer who will be using the software system.

Second Actor: 
- [ ] An actor that supports the first actor. The second actor may be a system or another external entity that interacts with the software system.

Stakeholders: 
- [ ] Anyone who benefits in a direct or indirect way from the system which is being developed.

Non-Functional-Requirement (NFR)
- [ ] quality
- [ ] security
- [ ] performance 
- [ ] end user does understand this stuff **but we** do

### Chapter 8
UML Sequence Diagram used for:
- [ ] The UML sequence diagram can be used for behavioral modeling.

What is a Use Case?
- [ ] A use case is a description of how a user (or actor) interacts with a software system to achieve a specific goal.
- [ ] Use cases Trigger goes from one case to another



### Phases
inception phase:
- [ ] basic idea

elaboration phase:
- [ ] evolution 

elicitation phase:
- [ ] end goal

Negotiation Phase :
- [ ] rank (priority) requirements 

construction phase:
- [ ] Is identical to the construction activity defined for the generic software process. 

transition phase:
- [ ] Encompasses the latter stages of the generic construction activity and the first part of the generic deployment (delivery and feedback) activity.

