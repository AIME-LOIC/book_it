import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState()=>_SignupScreenState();
}
class _SignupScreenState extends State<SignupScreen> {
  final _key=GlobalKey<FormState>();
  final _name=TextEditingController(),_email=TextEditingController(),_phone=TextEditingController(),_password=TextEditingController(),_confirm=TextEditingController();
  bool _busy=false,_obscure=true;
  @override void dispose(){_name.dispose();_email.dispose();_phone.dispose();_password.dispose();_confirm.dispose();super.dispose();}
  Future<void> _submit() async {
    if(!(_key.currentState?.validate()??false)) return;
    setState(()=>_busy=true);
    try {
      final name=await AuthService.register(name:_name.text,email:_email.text,phone:_phone.text,password:_password.text);
      if(!mounted)return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder:(_)=>HomeScreen(userName:name)),(_)=>false);
    } on AuthException catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message)));
    } finally {if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    body:DecoratedBox(decoration:const BoxDecoration(gradient:AppColors.heroGradient),child:SafeArea(child:ListView(padding:const EdgeInsets.all(22),children:[
      const SizedBox(height:16),const Center(child:BrandLogo(size:72,onLight:true)),const SizedBox(height:18),
      const Text('Create your account',textAlign:TextAlign.center,style:TextStyle(color:AppColors.white,fontSize:27,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),Text('Join BookIt to book and manage your trips.',textAlign:TextAlign.center,style:TextStyle(color:AppColors.white.withValues(alpha:.85))),
      const SizedBox(height:24),
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:AppColors.white,borderRadius:BorderRadius.circular(26)),child:Form(key:_key,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _field('Full name',_name,Icons.person_outline,validator:(v)=>(v?.trim().isEmpty??true)?'Enter your name':null),
        const SizedBox(height:14),
        _field('Email address',_email,Icons.email_outlined,type:TextInputType.emailAddress,validator:(v)=>(v==null||!v.contains('@')||!v.contains('.'))?'Enter a valid email':null),
        const SizedBox(height:14),
        _field('Phone number',_phone,Icons.phone_outlined,type:TextInputType.phone,validator:(v)=>(v?.trim().length??0)<9?'Enter a valid phone number':null),
        const SizedBox(height:14),
        _field('Password',_password,Icons.lock_outline,obscure:_obscure,suffix:IconButton(onPressed:()=>setState(()=>_obscure=!_obscure),icon:Icon(_obscure?Icons.visibility_off:Icons.visibility)),validator:(v)=>(v?.length??0)<6?'Use at least 6 characters':null),
        const SizedBox(height:14),
        _field('Confirm password',_confirm,Icons.lock_reset_outlined,obscure:true,validator:(v)=>v!=_password.text?'Passwords do not match':null),
        const SizedBox(height:22),SizedBox(height:52,child:FilledButton(onPressed:_busy?null:_submit,child:_busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):const Text('Create account'))),
      ]))),
      const SizedBox(height:14),TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:const Text('Already have an account? Sign in',style:TextStyle(color:AppColors.white,fontWeight:FontWeight.w700))),
    ]))));
  Widget _field(String label,TextEditingController c,IconData icon,{TextInputType type=TextInputType.text,bool obscure=false,Widget? suffix,String? Function(String?)? validator})=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:AppColors.textDark)),const SizedBox(height:7),
    TextFormField(controller:c,keyboardType:type,obscureText:obscure,validator:validator,decoration:InputDecoration(hintText:label,prefixIcon:Icon(icon,color:AppColors.primary),suffixIcon:suffix)),
  ]);
}
